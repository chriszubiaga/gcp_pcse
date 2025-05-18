# Google Cloud Lab Notes: Create an Internal Load Balancer (GSP216)

## Overview

**Core Concept:** Google Cloud Internal TCP/UDP Load Balancing allows you to run and scale your services behind a private, internal IP address. This IP address is accessible only to your internal virtual machine (VM) instances within the same Virtual Private Cloud (VPC) network or connected networks (e.g., via VPC Network Peering, Cloud VPN).

This lab walks through creating two managed instance groups in the same region and then configuring an Internal Load Balancer to distribute traffic to these instance groups as backends.

![Diagram](assets\internal_load_balancer.png
)

## Objectives

* Create HTTP and health check firewall rules for internal traffic.
* Configure instance templates to define backend VM specifications.
* Create managed instance groups for scalable and resilient backends.
* Configure and test an Internal Load Balancer.

## Setup and Requirements

* Standard lab setup (browser, temporary credentials).
* The lab utilizes a pre-configured VPC network named `my-internal-app` with two subnets: `subnet-a` and `subnet-b`. These subnets are in the same region, which is a requirement for Internal Load Balancing (as it's a regional service).

## Task 1: Configure HTTP and Health Check Firewall Rules

**Core Concepts:**

* **Firewall Rules for Internal Load Balancers:**
    * Allow traffic from clients within the VPC to the backend instances on the required ports (e.g., HTTP on port 80). In this lab, a source range of `10.10.0.0/16` is used, likely encompassing the client VMs and possibly the load balancer's IP range.
    * Allow traffic from Google Cloud health checkers (`130.211.0.0/22` and `35.191.0.0/16`) to the backend instances on the health check port.
* **Target Tags:** Used to apply firewall rules selectively to instances tagged appropriately (e.g., `lb-backend`).

**1. Explore the `my-internal-app` Network**

* This network is pre-configured with `subnet-a` and `subnet-b` in `europe-west1`.
* Pre-existing firewall rules allow RDP, SSH, and ICMP.

**2. Create the HTTP Firewall Rule**

* **Purpose:** Allow HTTP traffic to the backend instances from within the network (and potentially from the internet for initial setup if instances had external IPs, though ILB backends typically don't). The source range `10.10.0.0/16` allows internal clients to reach the backends.
* **Configuration Highlights:**
    * **Name:** `app-allow-http`
    * **Network:** `my-internal-app`
    * **Targets:** `Specified target tags`
    * **Target tags:** `lb-backend`
    * **Source filter:** `IPv4 Ranges`
    * **Source IPv4 ranges:** `10.10.0.0/16`
    * **Protocols and ports:** `tcp:80`
* **gcloud CLI command:**
    ```bash
    gcloud compute firewall-rules create app-allow-http \
        --network=my-internal-app \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:80 \
        --source-ranges=10.10.0.0/16 \
        --target-tags=lb-backend
    ```

**3. Create the Health Check Firewall Rule**

* **Purpose:** Allow health check probes from Google's health checking systems.
* **Configuration Highlights:**
    * **Name:** `app-allow-health-check`
    * **Network:** `my-internal-app`
    * **Targets:** `Specified target tags`
    * **Target tags:** `lb-backend`
    * **Source filter:** `IPv4 Ranges`
    * **Source IPv4 ranges:** `130.211.0.0/22,35.191.0.0/16`
    * **Protocols and ports:** `tcp` (or `tcp:80` if the health check is specifically on port 80)
* **gcloud CLI command:**
    ```bash
    gcloud compute firewall-rules create app-allow-health-check \
        --network=my-internal-app \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp \
        --source-ranges=130.211.0.0/22,35.191.0.0/16 \
        --target-tags=lb-backend
    ```

## Task 2: Configure Instance Templates and Create Instance Groups

**Core Concepts:**

* **Instance Templates:** Define the configuration for VMs in a managed instance group (MIG). This ensures all backend instances are identical.
* **Managed Instance Groups (MIGs):** Used as backends for the load balancer. For high availability, MIGs are typically deployed across multiple zones within a region. Internal Load Balancers are regional, so their backends must reside in the same region.
* **Startup Scripts:** Used to automate instance setup, such as installing web servers.
* **No External IP:** Backend instances for an Internal Load Balancer generally do not need (and often should not have) external IP addresses, as they are only accessed internally.

**1. Configure Instance Templates**

* Two templates are created: `instance-template-1` (for `subnet-a`) and `instance-template-2` (for `subnet-b`).
* **Key Configuration for `instance-template-1`:**
    * **Name:** `instance-template-1`
    * **Location:** Global (template resource itself)
    * **Machine Type:** `e2-micro`
    * **Network tags:** `lb-backend`
    * **Network Interface:**
        * **Network:** `my-internal-app`
        * **Subnetwork:** `subnet-a`
        * **External IPv4 Address:** `None`
    * **Metadata:**
        * **Key:** `startup-script-url`
        * **Value:** `gs://cloud-training/gcpnet/ilb/startup.sh` (installs Apache, customizes page)
* **gcloud CLI command for `instance-template-1`:**
    ```bash
    gcloud compute instance-templates create instance-template-1 \
        --machine-type=e2-micro \
        --network=my-internal-app \
        --subnet=subnet-a \
        --region=europe-west1 \
        --tags=lb-backend \
        --metadata=startup-script-url=gs://cloud-training/gcpnet/ilb/startup.sh \
        --no-address 
    ```
* `instance-template-2` is created by copying `instance-template-1` and changing the **Subnetwork** to `subnet-b`.
* **gcloud CLI command for `instance-template-2`:**
    ```bash
    gcloud compute instance-templates create instance-template-2 \
        --machine-type=e2-micro \
        --network=my-internal-app \
        --subnet=subnet-b \
        --region=europe-west1 \
        --tags=lb-backend \
        --metadata=startup-script-url=gs://cloud-training/gcpnet/ilb/startup.sh \
        --no-address
    ```

**2. Create Managed Instance Groups (MIGs)**

* Two MIGs are created: `instance-group-1` (in a zone for `subnet-a`) and `instance-group-2` (in a different zone for `subnet-b` within the same region).
* **Key Configuration for `instance-group-1`:**
    * **Name:** `instance-group-1`
    * **Instance template:** `instance-template-1`
    * **Location:** Single-zone (MIG is zonal, but an ILB can have backends from multiple zones in its region)
    * **Zone:** A zone within `YOUR_REGION` where `subnet-a` is located.
    * **Autoscaling:** Min 1, Max 1 instance (for this lab, effectively fixed size), Target CPU 80%, Initialization period 45s.
* **gcloud CLI command for `instance-group-1`:**
    ```bash
    gcloud compute instance-groups managed create instance-group-1 \
        --template=instance-template-1 \
        --size=1 \
        --zone=europe-west1-c
    # Autoscaler (though min=max=1 makes it less dynamic in this lab)
    gcloud compute instance-groups managed set-autoscaling instance-group-1 \
        --zone=europe-west1-c \
        --max-num-replicas=1 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.8 \
        --cool-down-period=45
    ```
* `instance-group-2` is configured similarly in a different zone using `instance-template-2`.
* **gcloud CLI command for `instance-group-2`:**
    ```bash
    gcloud compute instance-groups managed create instance-group-2 \
        --template=instance-template-2 \
        --size=1 \
        --zone=europe-west1-b
    gcloud compute instance-groups managed set-autoscaling instance-group-2 \
        --zone=europe-west1-b \
        --max-num-replicas=1 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.8 \
        --cool-down-period=45
    ```

**3. Verify Backends and Create Utility VM**

* Confirm instances are created for `instance-group-1` and `instance-group-2`.
* Create a `utility-vm` to test connectivity to the ILB later. This VM must be in the same VPC network (`my-internal-app`) and region as the ILB.
* **`utility-vm` Configuration:**
    * **Name:** `utility-vm`
    * **Region/Zone:** Same region as MIGs, placed in `subnet-a`.
    * **Machine Type:** `e2-micro`
    * **Network Interface:**
        * **Network:** `my-internal-app`
        * **Subnetwork:** `subnet-a`
        * **Primary internal IPv4 address:** `10.10.20.50` (Custom ephemeral)
* **gcloud CLI command for `utility-vm`:**
    ```bash
    gcloud compute instances create utility-vm \
        --machine-type=e2-micro \
        --network=my-internal-app \
        --subnet=subnet-a \
        --private-network-ip=10.10.20.50 \
        --zone=europe-west1-c # Ensure this zone is where subnet-a is available
    ```
* SSH into `utility-vm` and `curl` the internal IPs of the backend instances (e.g., `10.10.20.2`, `10.10.30.2`) to verify their individual web pages.
    ```bash
    # From utility-vm SSH session
    curl 10.10.20.2 # Check output for instance-group-1 details
    curl 10.10.30.2 # Check output for instance-group-2 details
    exit
    ```

## Task 3: Configure the Internal Load Balancer

**Core Concepts:**

* **Internal TCP/UDP Load Balancer:** A regional, passthrough load balancer. It distributes traffic among instances in the same region.
* **Components:**
    * **Regional Forwarding Rule (Frontend):** Defines the internal IP address, protocol (TCP/UDP), and port(s) that the load balancer listens on. The IP address is chosen from a subnet in the load balancer's region.
    * **Regional Backend Service:** Specifies the backend instance groups, health check, and session affinity.
    * **Health Check:** Determines the health of backend instances.

**1. Start Configuration**

* Navigate to **Network Services > Load balancing**.
* Select **Network Load Balancer (TCP/UDP/SSL)**.
* Select **Passthrough load balancer** and **Internal**.
* **Configuration:**
    * **Name:** `my-ilb`
    * **Region:** `europe-west1` (same region as `my-internal-app` subnets)
    * **Network:** `my-internal-app`

**2. Configure the Regional Backend Service**

* **Instance groups:** Add `instance-group-1` (zone `europe-west1-c`) and `instance-group-2` (zone `europe-west1-b`).
* **Health Check:**
    * **Name:** `my-ilb-health-check`
    * **Protocol:** TCP
    * **Port:** 80
* **gcloud CLI commands:**
    * Create health check:
        ```bash
        gcloud compute health-checks create tcp my-ilb-health-check \
            --port=80 \
            --region=europe-west1
        ```
    * Create backend service:
        ```bash
        gcloud compute backend-services create my-ilb-backend-service \
            --load-balancing-scheme=INTERNAL \
            --protocol=TCP \
            --health-checks=my-ilb-health-check \
            --region=europe-west1
        ```
    * Add instance groups to backend service:
        ```bash
        gcloud compute backend-services add-backend my-ilb-backend-service \
            --instance-group=instance-group-1 \
            --instance-group-zone=europe-west1-c \
            --region=europe-west1
        gcloud compute backend-services add-backend my-ilb-backend-service \
            --instance-group=instance-group-2 \
            --instance-group-zone=europe-west1-b \
            --region=europe-west1
        ```

**3. Configure the Frontend (Forwarding Rule)**

* **Subnetwork:** `subnet-b` (The ILB's IP will be from this subnet)
* **Internal IP Address:** Static, custom IP `10.10.30.5` (named `my-ilb-ip`).
* **Port number:** `80`
* **gcloud CLI command:**
    ```bash
    gcloud compute forwarding-rules create my-ilb-forwarding-rule \
        --load-balancing-scheme=INTERNAL \
        --network=my-internal-app \
        --subnet=subnet-b \
        --address=10.10.30.5 \
        --ports=80 \
        --region=europe-west1 \
        --backend-service=my-ilb-backend-service
    ```

**4. Review and Create**

* Review configurations and create the load balancer.

## Task 4: Test the Internal Load Balancer

**Core Concept:** Verify that traffic sent to the ILB's internal IP address is distributed across the healthy backend instances.

**1. Access the Internal Load Balancer**

* SSH into `utility-vm`.
* Use `curl` to access the ILB's IP address (`10.10.30.5`):
    ```bash
    # From utility-vm SSH session
    curl 10.10.30.5
    ```
* Run the command multiple times.
* **Expected Output:** You should see responses alternating (or distributed) between instances in `instance-group-1` and `instance-group-2`, indicated by the "Server Hostname" and "Server Location" in the HTML response from the startup script. This confirms the ILB is working and distributing traffic.

This lab demonstrates the fundamental setup of an Internal TCP/UDP Load Balancer, crucial for applications that require private, scalable, and resilient internal load balancing within a Google Cloud VPC network.