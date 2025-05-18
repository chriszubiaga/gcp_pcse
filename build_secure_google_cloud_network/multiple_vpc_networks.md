
# Google Cloud VPC and VM Connectivity Lab Notes

## Overview

This lab focuses on understanding and configuring Virtual Private Cloud (VPC) networks in Google Cloud. Key activities include creating custom VPC networks, setting up firewall rules, launching Virtual Machine (VM) instances within these networks, and testing connectivity between them. The lab also explores the use of multiple network interfaces on a single VM.

**Network Diagram Components:**

![Diagram](.\assets\vpc_network.png)

* **mynetwork (pre-created):** An auto mode network with two VM instances (`mynet-vm-1`, `mynet-vm-2`) and firewall rules.
* **managementnet (to be created):** A custom mode network with `managementsubnet-1` and `managementnet-vm-1`.
* **privatenet (to be created):** A custom mode network with `privatesubnet-1`, `privatesubnet-2`, and `privatenet-vm-1`.
* **vm-appliance (to be created):** A VM with multiple network interfaces connecting to `privatenet`, `managementnet`, and `mynetwork`.

## Objectives

* Create custom mode VPC networks and associated firewall rules.
* Create VM instances within these VPCs using Compute Engine.
* Analyze network connectivity between VMs across different VPC networks and zones.
* Configure and test a VM instance with multiple network interfaces.

## Setup and Requirements

* Use a standard internet browser (Chrome recommended, in Incognito mode).
* Labs are timed and cannot be paused.
* Use only the temporary credentials provided by the lab.
* Activate **Cloud Shell** for command-line operations.
    * Cloud Shell is a VM with development tools and a persistent 5GB home directory.
    * `gcloud` is the command-line tool for Google Cloud, pre-installed in Cloud Shell.

**Important Cloud Shell Commands (Optional Setup):**

* List active account:
    ```bash
    gcloud auth list
    ```
* List project ID:
    ```bash
    gcloud config list project
    ```

## Task 1: Create Custom Mode VPC Networks with Firewall Rules

**Key Points:**

* **Auto mode networks** (like `default` and the pre-created `mynetwork`) automatically create subnets in each Google Cloud region.
* **Custom mode networks** start with no subnets, providing full control over subnet creation. `managementnet` and `privatenet` will be custom mode.
* Firewall rules control ingress/egress traffic to VM instances.

**1. Create the `managementnet` Network (via Cloud Console)**

* **Name:** `managementnet`
* **Subnet creation mode:** Custom
* **Subnet details:**
    * **Name:** `managementsubnet-1`
    * **Region:** `us-west1`
    * **IPv4 range:** `10.130.0.0/20`
* The console provides an "EQUIVALENT COMMAND LINE" option to see the `gcloud` commands.

**2. Create the `privatenet` Network (via Cloud Shell)**

* Create the network:
    ```bash
    gcloud compute networks create privatenet --subnet-mode=custom
    ```
* Create `privatesubnet-1`:
    ```bash
    gcloud compute networks subnets create privatesubnet-1 --network=privatenet --region=us-west1 --range=172.16.0.0/24
    ```
* Create `privatesubnet-2`:
    ```bash
    gcloud compute networks subnets create privatesubnet-2 --network=privatenet --region=europe-west1 --range=172.20.0.0/20
    ```
* List available VPC networks:
    ```bash
    gcloud compute networks list
    ```
* List available VPC subnets (sorted by network):
    ```bash
    gcloud compute networks subnets list --sort-by=NETWORK
    ```

**3. Create Firewall Rules for `managementnet` (via Cloud Console)**

* **Name:** `managementnet-allow-icmp-ssh-rdp`
* **Network:** `managementnet`
* **Targets:** All instances in the network
* **Source filter:** IPv4 Ranges
* **Source IPv4 ranges:** `0.0.0.0/0` (allows traffic from any IP address)
* **Protocols and ports:**
    * `tcp`: `22` (SSH), `3389` (RDP)
    * `icmp` (for ping)

**4. Create Firewall Rules for `privatenet` (via Cloud Shell)**

* Create `privatenet-allow-icmp-ssh-rdp` firewall rule:
    ```bash
    gcloud compute firewall-rules create privatenet-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=privatenet --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0
    ```
* List all firewall rules (sorted by network):
    ```bash
    gcloud compute firewall-rules list --sort-by=NETWORK
    ```

## Task 2: Create VM Instances

**Key Points:**

* VM instances are created within specific zones and attached to subnets of VPC networks.

**1. Create the `managementnet-vm-1` Instance (via Cloud Console)**

* **Name:** `managementnet-vm-1`
* **Region:** `us-west1`
* **Zone:** `us-west1-c`
* **Series:** E2
* **Machine Type:** `e2-micro`
* **Networking:**
    * **Network:** `managementnet`
    * **Subnetwork:** `managementsubnet-1`
* The console provides an "EQUIVALENT CODE" option (which shows the `gcloud` command).

**2. Create the `privatenet-vm-1` Instance (via Cloud Shell)**

* Create `privatenet-vm-1`:
    ```bash
    gcloud compute instances create privatenet-vm-1 --zone=us-west1-c --machine-type=e2-micro --subnet=privatesubnet-1
    ```
* List all VM instances (sorted by zone):
    ```bash
    gcloud compute instances list --sort-by=ZONE
    ```
* In the Cloud Console, you can add a "Network" column to the VM instances list for better visibility.

## Task 3: Explore the Connectivity Between VM Instances

**Key Points:**

* **External IP Addresses:** Accessible from the public internet, provided firewall rules allow the traffic (e.g., ICMP for ping).
* **Internal IP Addresses:**
    * VMs within the same VPC network can communicate using internal IP addresses, even if they are in different zones or regions. This is because VPC networks are global.
    * VMs in different VPC networks cannot communicate using internal IP addresses by default. Mechanisms like VPC Network Peering or Cloud VPN are required to enable such communication.

**1. Ping External IP Addresses**

* SSH into `mynet-vm-1`.
* From `mynet-vm-1`, ping the **external IP addresses** of `mynet-vm-2`, `managementnet-vm-1`, and `privatenet-vm-1`.
    ```bash
    ping -c 3 <EXTERNAL_IP_ADDRESS>
    ```
* **Expected Result:** All pings should be successful due to the permissive firewall rules allowing ICMP from `0.0.0.0/0`.

**2. Ping Internal IP Addresses**

* Still in the SSH terminal for `mynet-vm-1`.
* From `mynet-vm-1`, ping the **internal IP addresses** of other VMs.
    * Ping `mynet-vm-2` (same VPC `mynetwork`, different zone/region):
        ```bash
        ping -c 3 <MYNET-VM-2_INTERNAL_IP>
        ```
        **Expected Result:** Successful.
    * Ping `managementnet-vm-1` (different VPC `managementnet`, same region `us-west1`):
        ```bash
        ping -c 3 <MANAGEMENTNET-VM-1_INTERNAL_IP>
        ```
        **Expected Result:** Fails (100% packet loss).
    * Ping `privatenet-vm-1` (different VPC `privatenet`, same region `us-west1`):
        ```bash
        ping -c 3 <PRIVATENET-VM-1_INTERNAL_IP>
        ```
        **Expected Result:** Fails (100% packet loss).

**Question from Lab:**

> Which instance(s) should you be able to ping from mynet-region-1-vm using internal IP addresses?
>
> * managementnet-region-1-vm
> * privatenet-region-1-vm
> * **mynet-region-2-vm** (Correct)

**Explanation:** Only instances on the same VPC network (`mynetwork` in this case) can ping each other via internal IP addresses by default.

## Task 4: Create a VM Instance with Multiple Network Interfaces

**Key Points:**

* A VM can have multiple network interface controllers (NICs), allowing it to connect directly to several VPC networks.
* The number of allowed interfaces depends on the instance's machine type (e.g., `e2-standard-4` allows up to 4).
* The CIDR ranges of subnets connected to different NICs on the same VM must not overlap.
* Each NIC gets its own internal IP address within its respective subnet.
* The primary interface (usually `eth0`) gets the default route for traffic destined outside directly connected subnets.
* Internal DNS resolution by hostname typically resolves to the primary interface (`nic0`).

**1. Create the `vm-appliance` Instance (via Cloud Console)**

* **Name:** `vm-appliance`
* **Region:** `us-west1`
* **Zone:** `us-west1-c`
* **Series:** E2
* **Machine Type:** `e2-standard-4` (supports multiple NICs)
* **Networking:**
    * **Network interface 1 (nic0 - primary):**
        * **Network:** `privatenet`
        * **Subnetwork:** `privatesubnet-1`
    * **Add a network interface (nic1):**
        * **Network:** `managementnet`
        * **Subnetwork:** `managementsubnet-1`
    * **Add a network interface (nic2):**
        * **Network:** `mynetwork`
        * **Subnetwork:** `mynetwork` (select the one in `us-west1` if multiple options appear, though any subnet in `mynetwork` will demonstrate the concept)

**2. Explore the Network Interface Details**

* In the Cloud Console (Compute Engine > VM instances > `vm-appliance`), inspect `nic0`, `nic1`, and `nic2` to see their attached subnets and internal IP addresses.
* SSH into `vm-appliance`.
* List network interfaces within the VM:
    ```bash
    sudo ifconfig
    ```
    * Observe `eth0`, `eth1`, `eth2` and their respective IP addresses.

**3. Explore the Network Interface Connectivity**

* Still in the SSH terminal for `vm-appliance`.
* Ping instances on the directly connected subnets using their internal IP addresses:
    * Ping `privatenet-vm-1` (connected via `eth0`):
        ```bash
        ping -c 3 <PRIVATENET-VM-1_INTERNAL_IP>
        ```
        **Expected Result:** Successful.
        * Also, try pinging by hostname (should work for the primary interface's network):
            ```bash
            ping -c 3 privatenet-vm-1
            ```
            **Expected Result:** Successful (VPC internal DNS resolves to primary interface).
    * Ping `managementnet-vm-1` (connected via `eth1`):
        ```bash
        ping -c 3 <MANAGEMENTNET-VM-1_INTERNAL_IP>
        ```
        **Expected Result:** Successful.
    * Ping `mynet-vm-1` (in `us-west1`, connected via `eth2`):
        ```bash
        ping -c 3 <MYNET-VM-1_INTERNAL_IP>
        ```
        **Expected Result:** Successful.
    * Ping `mynet-vm-2` (in `europe-west1`, on `mynetwork` but not directly connected subnet for `eth2`'s specific configuration, communication relies on routing):
        ```bash
        ping -c 3 <MYNET-VM-2_INTERNAL_IP>
        ```
        **Expected Result:** **Fails.**
        * **Reason:** Traffic to `mynet-vm-2` (which is not in a directly connected subnet listed in the routing table for `eth2`) will use the default route associated with the primary interface `eth0`. Since `eth0` is on `privatenet`, it cannot reach `mynet-vm-2` on `mynetwork` via that route.

* List the VM's routing table:
    ```bash
    ip route
    ```
    * Observe the default route via `eth0` (e.g., `default via 172.16.0.1 dev eth0`).
    * Observe routes for each directly connected subnet via `eth0`, `eth1`, and `eth2`.
    * The subnet of `mynet-vm-2` (if in a different region/subnet than `mynet-vm-1` on `mynetwork`) might not be directly listed, causing the ping to use the default route on `eth0`.
    * **Policy routing** can be configured to change this default behavior.


---

### Gcloud CLI

1. Create the `managementnet` network

```bash
gcloud compute networks create managementnet --project=qwiklabs-gcp-04-e2f1ea52dfcf --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional --bgp-best-path-selection-mode=legacy

gcloud compute networks subnets create managementsubnet-1 --project=qwiklabs-gcp-04-e2f1ea52dfcf --range=10.130.0.0/20 --stack-type=IPV4_ONLY --network=managementnet --region=us-west1
```

2. Create `privatenet` network

```bash
# Create privatesubnet
gcloud compute networks create privatenet --subnet-mode=custom

# Create privatesubnet-1
gcloud compute networks subnets create privatesubnet-1 --network=privatenet --region=us-west1 --range=172.16.0.0/24

# Create privatesubnet-2
gcloud compute networks subnets create privatesubnet-2 --network=privatenet --region=europe-west1 --range=172.20.0.0/20

# Check the networks
gcloud compute networks list

# Check the subnets
gcloud compute networks subnets list --sort-by=NETWORK
```

3. Create firewall rules for `managementnet`

```bash
gcloud compute --project=qwiklabs-gcp-04-e2f1ea52dfcf firewall-rules create managementnet-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=managementnet --action=ALLOW --rules=tcp:22,tcp:3389 --source-ranges=0.0.0.0/0
```

4. Create firewall rules for `privatenet`
```bash
gcloud compute firewall-rules create privatenet-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=privatenet --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0
```

5. Create vminstances

- `managementnet-vm-1` in `managementsubnet-1`

    ```bash
    gcloud compute instances create managementnet-vm-1 --project=qwiklabs-gcp-04-e2f1ea52dfcf --zone=us-west1-c --machine-type=e2-micro --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=managementsubnet-1 --metadata=enable-osconfig=TRUE,enable-oslogin=true --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=1032733844795-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append --create-disk=auto-delete=yes,boot=yes,device-name=managementnet-vm-1,image=projects/debian-cloud/global/images/debian-12-bookworm-v20250513,mode=rw,size=10,type=pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ops-agent-policy=v2-x86-template-1-4-0,goog-ec-src=vm_add-gcloud --reservation-affinity=any && printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-x86-template-1-4-0\n' > config.yaml && gcloud compute instances ops-agents policies create goog-ops-agent-v2-x86-template-1-4-0-us-west1-c --project=qwiklabs-gcp-04-e2f1ea52dfcf --zone=us-west1-c --file=config.yaml && gcloud compute resource-policies create snapshot-schedule default-schedule-1 --project=qwiklabs-gcp-04-e2f1ea52dfcf --region=us-west1 --max-retention-days=14 --on-source-disk-delete=keep-auto-snapshots --daily-schedule --start-time=04:00 && gcloud compute disks add-resource-policies managementnet-vm-1 --project=qwiklabs-gcp-04-e2f1ea52dfcf --zone=us-west1-c --resource-policies=projects/qwiklabs-gcp-04-e2f1ea52dfcf/regions/us-west1/resourcePolicies/default-schedule-1
    ```

- `privatenet-vm-1` in `privatesubnet-1`

    ```bash
    gcloud compute instances create privatenet-vm-1 --zone=us-west1-c --machine-type=e2-micro --subnet=privatesubnet-1
    ```

Creating VM instances with multiple NICs
```bash
gcloud compute instances create vm-appliance --project=qwiklabs-gcp-04-e2f1ea52dfcf --zone=us-west1-c --machine-type=e2-standard-4 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=privatesubnet-1 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=managementsubnet-1 --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=mynetwork --metadata=enable-osconfig=TRUE,enable-oslogin=true --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=1032733844795-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append --create-disk=auto-delete=yes,boot=yes,device-name=vm-appliance,disk-resource-policy=projects/qwiklabs-gcp-04-e2f1ea52dfcf/regions/us-west1/resourcePolicies/default-schedule-1,image=projects/debian-cloud/global/images/debian-12-bookworm-v20250513,mode=rw,size=10,type=pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ops-agent-policy=v2-x86-template-1-4-0,goog-ec-src=vm_add-gcloud --reservation-affinity=any && printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-x86-template-1-4-0\n' > config.yaml && gcloud compute instances ops-agents policies create goog-ops-agent-v2-x86-template-1-4-0-us-west1-c --project=qwiklabs-gcp-04-e2f1ea52dfcf --zone=us-west1-c --file=config.yaml
```