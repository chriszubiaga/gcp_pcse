Application Load Balancer with Cloud Armor 

## Overview

  * **Google Cloud Application Load Balancer (ALB):** A global Layer 7 load balancer that distributes HTTP and HTTPS traffic to backends hosted in various Google Cloud regions. It operates at the edge of Google's network, meaning user traffic enters the Google network at the Point of Presence (POP) closest to the user.
  * **Cloud Armor:** A network security service that provides DDoS protection and Web Application Firewall (WAF) capabilities for applications and services hosted on Google Cloud, often integrated with ALBs. It allows you to create IP allow/denylist policies to filter traffic at the edge.

This lab demonstrates configuring an Application Load Balancer with global backends, stress-testing it, and then securing it by denylisting an IP address using Cloud Armor.


![Diagram](assets\cloud_armor.png)

## Objectives

* Create HTTP and health check firewall rules.
* Configure instance templates for consistent VM creation.
* Create managed instance groups for scalable backends.
* Configure an Application Load Balancer supporting both IPv4 and IPv6.
* Perform a stress test on the Application Load Balancer.
* Use Cloud Armor to denylist an IP address, restricting access.

## Task 1: Configure HTTP and Health Check Firewall Rules

** for Exam:**

* **Firewall Rules:** Essential for controlling traffic to and from your VPC network and VM instances.
* **Health Check IP Ranges:** Load balancers use specific Google-owned IP ranges (`130.211.0.0/22` and `35.191.0.0/16`) to perform health checks on backend instances. These ranges must be allowed by firewall rules.
* **Target Tags:** A common way to apply firewall rules to a specific set of VM instances.

**1. Create the HTTP Firewall Rule**

* **Purpose:** Allow external HTTP traffic (port 80) to backend instances.
* **Configuration Highlights:**
    * **Name:** `default-allow-http`
    * **Network:** `default`
    * **Targets:** `Specified target tags`
    * **Target tags:** `http-server`
    * **Source filter:** `IPv4 Ranges`
    * **Source IPv4 ranges:** `0.0.0.0/0` (allows traffic from any IP)
    * **Protocols and ports:** `tcp:80`
* **gcloud CLI command:**
    ```bash
    gcloud compute firewall-rules create default-allow-http \
        --network=default \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:80 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=http-server
    ```

**2. Create the Health Check Firewall Rule**

* **Purpose:** Allow traffic from Google Cloud's health checkers to backend instances.
* **Configuration Highlights:**
    * **Name:** `default-allow-health-check`
    * **Network:** `default`
    * **Targets:** `Specified target tags`
    * **Target tags:** `http-server`
    * **Source filter:** `IPv4 Ranges`
    * **Source IPv4 ranges:** `130.211.0.0/22`, `35.191.0.0/16`
    * **Protocols and ports:** `tcp` (the health check in this lab will be on port 80, covered by allowing all TCP ports from these sources, or you could specify TCP:80).
* **gcloud CLI command:**
    ```bash
    gcloud compute firewall-rules create default-allow-health-check \
        --network=default \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp \
        --source-ranges=130.211.0.0/22,35.191.0.0/16 \
        --target-tags=http-server
    ```
    *(Note: For TCP health checks on a specific port like 80, you might specify `--rules=tcp:80`)*

## Task 2: Configure Instance Templates and Create Instance Groups

** for Exam:**

* **Instance Templates:** Reusable definitions for VM instances, specifying machine type, boot disk image, labels, network tags, startup scripts, etc. This ensures consistency when creating multiple instances.
* **Managed Instance Groups (MIGs):** Create groups of identical VM instances based on an instance template. MIGs provide scalability (autoscaling), high availability (autohealing), and rolling updates.
* **Startup Scripts:** Scripts that run automatically when a VM instance boots up, used for installing software or performing initial configurations. The metadata key is `startup-script-url` or `startup-script`.
* **Autoscaling:** Automatically adjusts the number of instances in a MIG based on defined policies (e.g., CPU utilization, custom metrics).

**1. Configure Instance Templates**

* Two templates are created: `us-central1-template` and `us-east1-template`.
* **Key Configuration for `us-central1-template`:**
    * **Name:** `us-central1-template`
    * **Location:** Global (Instance templates are global but specify regional resources).
    * **Machine Type:** `e2-micro` (Series E2)
    * **Network tags:** `http-server`
    * **Subnetwork:** `default` (targeting a subnet in `us-central1` - replace `us-central1` with the actual region name like `us-central1`)
    * **Metadata:**
        * **Key:** `startup-script-url`
        * **Value:** `gs://cloud-training/gcpnet/httplb/startup.sh`
* **gcloud CLI command for `$us-central1-template`:**
    ```bash
    gcloud compute instance-templates create us-central1-template --project=qwiklabs-gcp-00-195bac617508 --machine-type=e2-micro --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --region=us-central1 --tags=http-server 
    ```
* `us-east1-template` is created similarly, targeting a subnet in `us-east1`.
* **gcloud CLI command for `us-east1-template` (assuming similar parameters but for `us-east1`):**
    ```bash
    gcloud compute instance-templates create us-east1-template --project=qwiklabs-gcp-00-195bac617508 --machine-type=e2-micro --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --region=us-east1 --tags=http-server 
    ```

**2. Create Managed Instance Groups (MIGs)**

* Two MIGs are created: `us-central1-mig` and `us-east1-mig`.
* **Key Configuration for `us-central1-mig`:**
    * **Name:** `us-central1-mig`
    * **Instance template:** `us-central1-template`
    * **Location:** Multiple zones (within `us-central1`)
    * **Autoscaling:**
        * **Signal type:** CPU utilization
        * **Target CPU utilization:** 80%
        * **Minimum number of instances:** 1
        * **Maximum number of instances:** 2
        * **Initialization period:** 45 seconds
* **gcloud CLI command for `us-central1-mig`:**
    ```bash
    gcloud compute instance-groups managed create us-central1-mig \
        --template=us-central1-template \
        --size=1 \
        --region=us-central1
    # Autoscaler configuration:
    gcloud compute instance-groups managed set-autoscaling us-central1-mig \
        --region=us-central1 \
        --max-num-replicas=2 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.8 \
        --cool-down-period=45
    ```
* `us-east1-mig` is configured similarly.
* **gcloud CLI command for `us-east1-mig`:**
    ```bash
    gcloud compute instance-groups managed create us-east1-mig \
        --template=us-east1-template \
        --size=1 \
        --region=us-east1
    gcloud compute instance-groups managed set-autoscaling us-east1-mig \
        --region=us-east1 \
        --max-num-replicas=2 \
        --min-num-replicas=1 \
        --target-cpu-utilization=0.8 \
        --cool-down-period=45
    ```

**3. Verify Backends**

* Check VM instances via console or `gcloud compute instances list`.
* Accessing external IPs should show custom pages.

## Task 3: Configure the Application Load Balancer

** for Exam:**

* **ALB Components:**
    * **Frontend Configuration:** Global Forwarding Rules (IP, Port, Protocol) + Target HTTP(S) Proxy.
    * **Backend Service:** Defines how traffic is distributed, health checks, session affinity, etc.
    * **Health Checks:** Crucial for routing traffic only to healthy instances.
    * **URL Maps:** Route requests based on host/path to backend services.
* ALB is a global service. Backend services for global ALBs are also global but attach regional MIGs.

**1. Start Configuration & Naming**

* Load Balancer Name (conceptual, used for organizing): `http-lb`

**2. Create Health Check**

* **Name:** `http-health-check`
* **Protocol:** TCP (as per lab, though HTTP is common for ALBs)
* **Port:** 80
* **gcloud CLI command:**
    ```bash
    gcloud compute health-checks create tcp http-health-check \
        --port=80 \
        --global # For global ALB backend services
    ```
    *(If it were an HTTP health check: `gcloud compute health-checks create http http-health-check --port=80 --global`)*

**3. Create Backend Service**

* **Name:** `http-backend`
* **Protocol:** HTTP (for traffic between LB and backends)
* **Health Check:** `http-health-check`
* **Enable Logging:** Yes, Sample Rate: 1
* **gcloud CLI command:**
    ```bash
    gcloud compute backend-services create http-backend \
        --protocol=HTTP \
        --health-checks=http-health-check \
        --global \
        --enable-logging \
        --logging-sample-rate=1
    ```

**4. Add Backends to Backend Service**

* **Backend 1 (`us-central1-mig`):**
    * **Instance group:** `us-central1-mig` (ensure you specify the region for the MIG)
    * **Balancing mode:** `RATE`
    * **Maximum RPS per instance:** 50 (if `RATE` mode)
    * **Capacity:** 100%
* **gcloud CLI command for Backend 1:**
    ```bash
    gcloud compute backend-services add-backend http-backend \
        --instance-group=us-central1-mig \
        --instance-group-region=us-central1 \
        --balancing-mode=RATE \
        --max-rate-per-instance=50 \
        --capacity-scaler=1 \
        --global
    ```
* **Backend 2 (`us-east1-mig`):**
    * **Instance group:** `us-east1-mig`
    * **Balancing mode:** `UTILIZATION`
    * **Maximum backend utilization:** 80% (0.8)
    * **Capacity:** 100%
* **gcloud CLI command for Backend 2:**
    ```bash
    gcloud compute backend-services add-backend http-backend \
        --instance-group=us-east1-mig \
        --instance-group-region=us-east1 \
        --balancing-mode=UTILIZATION \
        --max-utilization=0.8 \
        --capacity-scaler=1 \
        --global
    ```

**5. Create URL Map**

* **Name:** `http-lb-url-map`
* **Default service:** `http-backend`
* **gcloud CLI command:**
    ```bash
    gcloud compute url-maps create http-lb-url-map \
        --default-service=http-backend \
        --global
    ```

**6. Create Target HTTP Proxy**

* **Name:** `http-lb-proxy`
* **URL Map:** `http-lb-url-map`
* **gcloud CLI command:**
    ```bash
    gcloud compute target-http-proxies create http-lb-proxy \
        --url-map=http-lb-url-map \
        --global
    ```

**7. Create Frontend Global Forwarding Rules**

* **IPv4 Frontend:**
    * **Name:** `http-lb-ipv4-forwarding-rule` (example name)
    * **IP version:** IPv4
    * **IP address:** Ephemeral (auto-assigned)
    * **Port:** 80
    * **Target:** `http-lb-proxy`
* **gcloud CLI command for IPv4:**
    ```bash
    gcloud compute forwarding-rules create http-lb-ipv4-forwarding-rule \
        --target-http-proxy=http-lb-proxy \
        --ports=80 \
        --global
    ```
* **IPv6 Frontend:**
    * **Name:** `http-lb-ipv6-forwarding-rule` (example name)
    * **IP version:** IPv6
    * **IP address:** Auto-allocate
    * **Port:** 80
    * **Target:** `http-lb-proxy`
* **gcloud CLI command for IPv6:**
    ```bash
    gcloud compute forwarding-rules create http-lb-ipv6-forwarding-rule \
        --target-http-proxy=http-lb-proxy \
        --ports=80 \
        --ip-version=IPV6 \
        --global
    ```
* Note the assigned IPs: `[LB_IP_v4]` and `[LB_IP_v6]`. You can get these using:
    ```bash
    gcloud compute forwarding-rules describe http-lb-ipv4-forwarding-rule --global --format="get(IPAddress)"
    gcloud compute forwarding-rules describe http-lb-ipv6-forwarding-rule --global --format="get(IPAddress)"
    ```

## Task 4: Test the Application Load Balancer

** for Exam:**

* **Global Routing:** ALBs route users to the closest backend region with available capacity.
* **Propagation Time:** It can take several minutes for load balancer configurations to propagate.

**1. Access the Application Load Balancer**

* Open `http://[LB_IP_v4]` and `http://[LB_IP_v6]` (if applicable) in a browser.

**2. Stress Test the Application Load Balancer**

* Create a new VM (`siege-vm`) in `Region 3` / `Zone 3`.
* **gcloud CLI command to create `siege-vm`:**
    ```bash
    gcloud compute instances create siege-vm \
        --machine-type=e2-standard-1 \
        --zone=YOUR_ZONE_3 \
        --image-family=debian-11 \
        --image-project=debian-cloud 
        # Using a standard machine type as e2-micro might be too small for siege.
        # Lab used E2 series, but didn't specify size for siege-vm, so e2-standard-1 is a guess.
    ```
* SSH into `siege-vm`:
    ```bash
    gcloud compute ssh siege-vm --zone=YOUR_ZONE_3
    ```
* Install `siege` on `siege-vm`:
    ```bash
    sudo apt-get update
    sudo apt-get -y install siege
    ```
* Set the LB IP as an environment variable:
    ```bash
    export LB_IP=[LB_IP_v4] # Replace with actual IPv4 of the LB
    ```
* Run the stress test:
    ```bash
    siege -c 150 -t120s http://$LB_IP
    ```
* **Observation:** Monitor traffic distribution in the Cloud Console (Load balancing > Backends > http-backend > Monitoring).

## Task 5: Denylist the `siege-vm` (Using Cloud Armor)

** for Exam:**

* **Cloud Armor Security Policies:** Sets of rules to filter traffic. Attached to backend services.
* **Rule Components:** Match condition, action (allow/deny), priority.
* **Default Rule:** Applied if no other rule matches.

**1. Create the Security Policy**

* Note the External IP of `siege-vm` as `[SIEGE_IP]`.
    ```bash
    # On siege-vm or from your local machine if you know the name/zone:
    gcloud compute instances describe siege-vm --zone=YOUR_ZONE_3 --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
    ```
* **Configuration:**
    * **Name:** `denylist-siege`
    * **Default rule action:** `Allow`
* **gcloud CLI command to create policy:**
    ```bash
    gcloud compute security-policies create denylist-siege \
        --default-action=ALLOW \
        --description="Policy to denylist siege VM"
    ```
* **Add a Deny Rule:**
    * **Condition:** Match `[SIEGE_IP]`
    * **Action:** `Deny`
    * **Response code:** `403 (Forbidden)`
    * **Priority:** `1000`
* **gcloud CLI command to add rule:**
    ```bash
    gcloud compute security-policies rules create 1000 \
        --policy=denylist-siege \
        --src-ip-ranges=[SIEGE_IP] \
        --action=deny-403
    ```
* **Attach Policy to Backend Service:**
    * **Target:** `http-backend`
* **gcloud CLI command to attach policy:**
    ```bash
    gcloud compute backend-services update http-backend \
        --security-policy=denylist-siege \
        --global
    ```

**2. Verify the Security Policy**

* **From `siege-vm`:**
    * Attempt to access the load balancer:
        ```bash
        curl http://$LB_IP
        ```
        *Expected Output: `403 Forbidden` (after policy propagation).*
* **From your browser:**
    * Access `http://[LB_IP_v4]`. Should still be accessible.
* **Explore Security Policy Logs:**
    * Use Cloud Logging. Filter for `resource.type="http_load_balancer"` and look for `jsonPayload.enforcedSecurityPolicy`.
