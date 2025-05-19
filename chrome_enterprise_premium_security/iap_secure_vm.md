# Securing Virtual Machines with IAP TCP Forwarding

## Overview

This lab demonstrates how to use Identity-Aware Proxy (IAP) TCP forwarding to enable secure administrative access (SSH and RDP) to Google Compute Engine VM instances that do not have external IP addresses. This method avoids exposing VMs directly to the internet, enhancing security by relying on user identity and IAM permissions for access control.

## What You'll Learn

* Enable IAP TCP forwarding in a Google Cloud project.
* Create Linux and Windows VM instances without external IP addresses.
* Test initial connectivity (or lack thereof) to these instances.
* Configure firewall rules required for IAP TCP forwarding.
* Grant IAM permissions necessary for users/service accounts to use IAP TCP forwarding.
* Use IAP Desktop (from a Windows jump host) to connect to instances.
* Demonstrate IAP tunneling for SSH and RDP connections using `gcloud` commands.

## Setup

* Standard Google Cloud lab environment.
* An RDP client is needed if you intend to RDP from your local machine to the `windows-connectivity` VM (though the lab primarily focuses on actions *from within* `windows-connectivity`).

## Task 1: Enable IAP TCP Forwarding in Your Google Cloud Project

IAP TCP forwarding relies on the "Cloud Identity-Aware Proxy API."

* **Enable the API:**
    * **UI Steps:**
        1.  Open the **Navigation Menu** and select **APIs and Services > Library**.
        2.  Search for `IAP` and select **Cloud Identity-Aware Proxy API**.
        3.  Click **Enable**.
    * **gcloud CLI command:**
        ```bash
        gcloud services enable iap.googleapis.com
        ```

## Task 2: Create Linux and Windows Instances

Three instances will be created:
* `linux-iap`: Linux VM, no external IP.
* `windows-iap`: Windows VM, no external IP.
* `windows-connectivity`: Windows VM with an external IP, used as a client/jump host to test IAP connections.

*(Replace `ZONE` with the specific zone provided in your lab, e.g., `us-central1-a`)*

```bash
export ZONE=us-east1-c
```

**1. Linux instance (`linux-iap`)**

* **Configuration:** No external IPv4 address.
* **gcloud CLI command:**
    ```bash
    gcloud compute instances create linux-iap \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --network-interface=network=default,no-address \
        --image-family=debian-11 \
        --image-project=debian-cloud
    ```

**2. Windows Demo VM (`windows-iap`)**

* **Configuration:** No external IPv4 address, Windows Server 2016 Datacenter.
* **gcloud CLI command:**
    ```bash
    gcloud compute instances create windows-iap \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --image-project=windows-cloud \
        --image-family=windows-2016 \
        --network-interface=network=default,no-address
    ```

**3. Windows Connectivity VM (`windows-connectivity`)**

* **Configuration:** With external IP, custom image `iap-desktop-v001` from `qwiklabs-resources` project, full access to all Cloud APIs.
* **gcloud CLI command:**
    ```bash
    gcloud compute instances create windows-connectivity \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --image-project=qwiklabs-resources \
        --image=iap-desktop-v001 \
        --scopes=https://www.googleapis.com/auth/cloud-platform
    ```

## Task 3: Test Connectivity to Your Linux and Windows Instances

* **Action:** Attempt to SSH to `linux-iap` and RDP to `windows-iap` using the standard methods from the Google Cloud Console (clicking the SSH/RDP buttons for the instances).
* **Expected Result:** Connection attempts will fail with messages indicating inability to connect, because these instances do not have external IP addresses and no IAP/firewall rules are configured yet to allow access.

## Task 4: Configure the Required Firewall Rules for IAP

A firewall rule is needed to allow traffic from IAP's known IP range to your instances on the SSH and RDP ports.

* **Configuration:**
    * **Name:** `allow-ingress-from-iap`
    * **Direction:** Ingress
    * **Target:** "All instances in the network" (as per lab; for better security, use target tags on `linux-iap` and `windows-iap`).
    * **Source filter:** IPv4 Ranges
    * **Source IPv4 Ranges:** `35.235.240.0/20`
    * **Protocols and ports:** TCP `22` (for SSH) and `3389` (for RDP).
* **gcloud CLI command:**
    ```bash
    gcloud compute firewall-rules create allow-ingress-from-iap \
        --network=default \
        --direction=INGRESS \
        --action=ALLOW \
        --rules=tcp:22,tcp:3389 \
        --source-ranges=35.235.240.0/20 \
        --description="Allow SSH and RDP ingress from IAP TCP forwarding service"
    ```

## Task 5: Grant Permissions to Use IAP TCP Forwarding

Users or service accounts require the "IAP-Secured Tunnel User" IAM role to connect to VMs via IAP.

* **Principals to grant access to:**
    1.  The service account of the `windows-connectivity` VM.
    2.  Your student lab account.
* **UI Steps (as per lab):**
    1.  Navigate to **Security > Identity-Aware Proxy**.
    2.  Switch to the **SSH AND TCP RESOURCES** tab.
    3.  Select the checkboxes for `linux-iap` and `windows-iap`.
    4.  In the right-side info panel, click **ADD PRINCIPAL**.
    5.  Enter the service account email for `windows-connectivity` (e.g., `PROJECT_NUMBER-compute@developer.gserviceaccount.com`).
    6.  Assign the role `Cloud IAP > IAP-Secured Tunnel User`. Click **SAVE**.
    7.  Click **ADD PRINCIPAL** again.
    8.  Enter your student email address.
    9.  Assign the role `Cloud IAP > IAP-Secured Tunnel User`. Click **SAVE**.

* **gcloud CLI commands (example for granting access to `linux-iap`):**
    * To grant the `windows-connectivity` service account access:
        ```bash
        # First, get the service account email for windows-connectivity
        SERVICE_ACCOUNT_EMAIL=$(gcloud compute instances describe windows-connectivity --zone=$ZONE --format='get(serviceAccounts[0].email)')

        # Grant to linux-iap
        gcloud compute instances add-iam-policy-binding linux-iap --zone=$ZONE \
            --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
            --role="roles/iap.tunnelResourceAccessor"

        # Grant to windows-iap
        gcloud compute instances add-iam-policy-binding windows-iap --zone=$ZONE \
            --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
            --role="roles/iap.tunnelResourceAccessor"
        ```
    * To grant your student account access:
        ```bash
        # Replace YOUR_STUDENT_EMAIL with your actual lab email and ZONE
        # Grant to linux-iap
        gcloud compute instances add-iam-policy-binding linux-iap --zone=$ZONE \
            --member="user:YOUR_STUDENT_EMAIL" \
            --role="roles/iap.tunnelResourceAccessor"

        # Grant to windows-iap
        gcloud compute instances add-iam-policy-binding windows-iap --zone=$ZONE \
            --member="user:YOUR_STUDENT_EMAIL" \
            --role="roles/iap.tunnelResourceAccessor"
        ```

## Task 6: Use IAP Desktop to Connect to the Windows and Linux Instances

IAP Desktop is a Windows application that provides a GUI to manage and connect to GCP instances via IAP.

1.  **RDP to `windows-connectivity` VM:**
    * Download the RDP file from the Compute Engine console for `windows-connectivity`.
    * Use credentials: Username: `student`, Password: `Learn123!` (as specified in the lab for this VM).
2.  **Inside `windows-connectivity` VM:**
    * Locate and open the **IAP Desktop** application (pre-installed on the custom image).
    * Sign in with your Google lab credentials. Allow requested permissions.
    * Add your lab project to IAP Desktop.
    * Once the project is added, `linux-iap` and `windows-iap` should be listed.
    * Double-click `windows-iap` to connect via IAP. If prompted, select "Generate new credentials" for the Windows instance.

## Task 7: Demonstrate Tunneling using SSH and RDP Connections (using `gcloud`)

This task is performed from within the `windows-connectivity` VM, using its Google Cloud SDK.

1.  **Connect to `windows-connectivity` VM** (if not already connected).
2.  **Open Google Cloud SDK Shell** on `windows-connectivity`.

**A. SSH to `linux-iap` via IAP Tunnel (Automatic with `gcloud`)**

* The `gcloud compute ssh` command automatically attempts to use IAP for instances without external IPs if permissions and firewall rules are correct.
    ```bash
    # From the Cloud SDK Shell on windows-connectivity
    # Replace ZONE with the zone of linux-iap
    gcloud compute ssh linux-iap --zone=ZONE
    ```
* Follow prompts (e.g., `Y` to continue, select zone if prompted, accept PuTTY security alert if applicable). A message should indicate IAP tunneling is being used.

**B. RDP to `windows-iap` via Manual IAP Tunnel (`gcloud`)**

1.  **Create an encrypted tunnel to `windows-iap` on port 3389:**
    ```bash
    # From the Cloud SDK Shell on windows-connectivity
    # Replace ZONE with the zone of windows-iap
    gcloud compute start-iap-tunnel windows-iap 3389 --local-host-port=localhost:0 --zone=ZONE
    ```
    * The command will output `Listening on port [LOCAL_PORT_NUMBER]`. Note this `LOCAL_PORT_NUMBER`. The tunnel will remain active in this SDK shell window.
2.  **Set/Get Windows Password for `windows-iap`:**
    * From the Google Cloud Console (either on your local machine or within the `windows-connectivity` browser):
        * Navigate to **Compute Engine > VM Instances**.
        * For `windows-iap`, click the arrow next to RDP, select "Set Windows password".
        * Note down the username and the new password.
3.  **Connect using Remote Desktop Connection on `windows-connectivity`:**
    * Open the "Remote Desktop Connection" application on the `windows-connectivity` VM.
    * For "Computer", enter: `localhost:[LOCAL_PORT_NUMBER]` (using the port number noted from the `start-iap-tunnel` command).
    * Click **Connect**.
    * Enter the Windows credentials (username and password) you obtained for `windows-iap`.
    * You should be RDP'd into `windows-iap` through the IAP tunnel.

## Key Concepts and Important Points

* **Identity-Aware Proxy (IAP) TCP Forwarding:**
    * Enables secure access (SSH, RDP, or other TCP protocols) to VM instances that do not have external IP addresses.
    * Traffic is tunneled through IAP, authenticating and authorizing users based on their Google identity and IAM permissions.
    * Enhances security by removing the need for bastion hosts with public IPs or complex VPN setups for administrative access.
    * Aligns with Zero Trust principles (access based on identity, not network location).

* **API Enablement:**
    * The "Cloud Identity-Aware Proxy API" must be enabled in the project for IAP TCP forwarding to function.

* **VMs without External IPs:**
    * A best practice for security is to create VMs without external IP addresses if they don't need to be directly accessible from the internet. IAP TCP forwarding provides a secure way to access such instances.

* **Firewall Rules for IAP:**
    * A crucial firewall rule is required to allow **ingress** traffic from IAP's specific source IP range: `35.235.240.0/20`.
    * This rule must allow traffic on the necessary ports for the services you want to access via IAP (e.g., TCP port `22` for SSH, TCP port `3389` for RDP).
    * The rule should target the instances intended to be accessed via IAP (e.g., by network tag or applying to "All instances in the network" if appropriate for the VPC design, though specific targeting is better).

* **IAM Permissions for IAP TCP Forwarding:**
    * The IAM role `roles/iap.tunnelResourceAccessor` (IAP-Secured Tunnel User) grants a principal (user, group, or service account) permission to create IAP tunnels to authorized resources.
    * This permission must be granted on the specific VM instances to be accessed, or at a higher level like project/folder if broader access is intended.

* **Connection Methods via IAP:**
    * **`gcloud compute ssh INSTANCE_NAME --zone=ZONE`**: For Linux instances without external IPs, `gcloud` automatically attempts to use IAP tunneling if the user has the necessary permissions and the IAP firewall rule is in place.
    * **`gcloud compute start-iap-tunnel INSTANCE_NAME INSTANCE_PORT --local-host-port=localhost:LOCAL_PORT --zone=ZONE`**:
        * Creates a secure tunnel from your local machine (or the machine running `gcloud`, like `windows-connectivity` in this lab) to the specified `INSTANCE_PORT` on the target `INSTANCE_NAME`.
        * The tunnel endpoint on your local machine will be `localhost:LOCAL_PORT` (if `:0` is used for `LOCAL_PORT`, `gcloud` picks an available port).
        * Standard clients (like Microsoft Remote Desktop Connection, SSH clients) can then connect to this local endpoint to reach the remote service.
    * **IAP Desktop:**
        * A Windows GUI application that simplifies connecting to GCP VMs via IAP.
        * It handles tunnel creation and manages connections, providing a user-friendly interface, especially for RDP.

* **Principle of Least Exposure:** By using IAP and avoiding external IPs on VMs, you significantly reduce the attack surface of your cloud resources.