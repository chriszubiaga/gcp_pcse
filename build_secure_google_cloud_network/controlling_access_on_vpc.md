# VPC Networks - Controlling Access

## Overview

The lab focuses on creating a secure and manageable web server deployment. You will set up two Nginx web servers on the default VPC network, control external HTTP access using tagged firewall rules, and investigate the functionalities of IAM service accounts and specific network-related roles. This setup aims to provide redundancy and granular control over network traffic, adhering to the principle of least privilege.

## Objectives

  * Create Nginx web servers on a VPC network.
  * Implement tagged firewall rules for access control.
  * Create and configure a service account with IAM roles.
  * Understand the permissions associated with the Network Admin and Security Admin roles.

## Setup and Requirements

  * Access to a standard internet browser (Chrome in Incognito mode is recommended).
  * The lab is timed and cannot be paused.
  * Use the temporary credentials provided by the lab for Google Cloud access.
  * **Activate Cloud Shell:** This provides command-line access to your Google Cloud resources. `gcloud` is the pre-installed command-line tool.
      * Optional: List active account: `gcloud auth list`
      * Optional: List project ID: `gcloud config list project`

## Task 1: Create the Web Servers

Two web servers, `blue` and `green`, will be created in the default VPC network. Nginx will be installed, and their welcome pages will be customized for identification.

**1. Create the `blue` Server (with network tag)**

  * Navigate to **Compute Engine \> VM instances** in the Cloud Console.
  * Click **Create Instance**.
  * **Configuration:**
      * **Name:** `blue`
      * **Region & Zone:** As specified by the lab (e.g., `REGION`, `ZONE`)
  * Under **Networking**:
      * **Network tags:** Add `web-server`. This tag will be used by a firewall rule to allow HTTP access.
  * Click **Create**.

**2. Create the `green` Server (without network tag)**

  * On the **VM instances** page, click **Create Instance**.
  * **Configuration:**
      * **Name:** `green`
      * **Region & Zone:** As specified by the lab (same as `blue` or different, per lab instructions)
  * Click **Create** (without adding any network tags).

**3. Install Nginx and Customize Welcome Pages**

  * **For the `blue` server:**
    1.  Click **SSH** to connect to the `blue` VM.
    2.  Install Nginx:
        ```bash
        sudo apt-get update
        sudo apt-get install nginx-light -y
        ```
    3.  Edit the Nginx welcome page:
        ```bash
        sudo nano /var/www/html/index.nginx-debian.html
        ```
    4.  Replace `<h1>Welcome to nginx!</h1>` with `<h1>Welcome to the blue server!</h1>`.
    5.  Save the file (CTRL+O, Enter) and exit nano (CTRL+X).
    6.  Verify the change:
        ```bash
        cat /var/www/html/index.nginx-debian.html
        ```
    7.  Close the SSH terminal:
        ```bash
        exit
        ```
  * **For the `green` server:**
    1.  Click **SSH** to connect to the `green` VM.
    2.  Install Nginx:
        ```bash
        sudo apt-get update
        sudo apt-get install nginx-light -y
        ```
    3.  Edit the Nginx welcome page:
        ```bash
        sudo nano /var/www/html/index.nginx-debian.html
        ```
    4.  Replace `<h1>Welcome to nginx!</h1>` with `<h1>Welcome to the green server!</h1>`.
    5.  Save and exit nano.
    6.  Verify the change:
        ```bash
        cat /var/www/html/index.nginx-debian.html
        ```
    7.  Close the SSH terminal:
        ```bash
        exit
        ```

## Task 2: Create the Firewall Rule and Test Connectivity

A tagged firewall rule will be created to allow HTTP traffic to instances with the `web-server` tag.

**1. Create the Tagged Firewall Rule**

  * Navigate to **VPC network \> Firewall** in the Cloud Console.
  * Note the `default-allow-internal` rule, which permits all internal traffic within the `default` network.
  * Click **Create Firewall Rule**.
  * **Configuration:**
      * **Name:** `allow-http-web-server`
      * **Network:** `default`
      * **Targets:** `Specified target tags`
      * **Target tags:** `web-server`
      * **Source filter:** `IPv4 Ranges`
      * **Source IPv4 ranges:** `0.0.0.0/0` (allows traffic from any external IP)
      * **Protocols and ports:** Select `Specified protocols and ports`.
          * Check `tcp` and enter port `80`.
          * (Lab might also ask to add `icmp` for ping)
  * Click **Create**.

**2. Create a `test-vm` Instance**

  * Open Cloud Shell.
  * Run the following command (replace `ZONE` with the appropriate zone):
    ```bash
    gcloud compute instances create test-vm --machine-type=e2-micro --subnet=default --zone=ZONE
    ```

**3. Test HTTP Connectivity**

  * In the Cloud Console, go to **Compute Engine \> VM instances** and note the internal and external IP addresses for `blue` and `green`.
  * SSH into `test-vm`.
  * **Test internal connectivity:**
      * Curl `blue` server's internal IP:
        ```bash
        curl <BLUE_SERVER_INTERNAL_IP>
        ```
        *Expected output: `<h1>Welcome to the blue server!</h1>`*
      * Curl `green` server's internal IP:
        ```bash
        curl <GREEN_SERVER_INTERNAL_IP>
        ```
        *Expected output: `<h1>Welcome to the green server!</h1>`*
        *(Internal access is allowed by the `default-allow-internal` firewall rule).*
  * **Test external connectivity:**
      * Curl `blue` server's external IP:
        ```bash
        curl <BLUE_SERVER_EXTERNAL_IP>
        ```
        *Expected output: `<h1>Welcome to the blue server!</h1>`*
        *(External access is allowed by the `allow-http-web-server` rule due to the `web-server` tag).*
      * Curl `green` server's external IP:
        ```bash
        curl <GREEN_SERVER_EXTERNAL_IP>
        ```
        *Expected output: The request will hang or time out. Press CTRL+C to stop.*
        *(External access is blocked because the `green` server does not have the `web-server` tag, so the `allow-http-web-server` rule does not apply to it).*

## Task 3: Explore the Network and Security Admin Roles

This task explores IAM permissions using a service account.

  * **Network Admin Role:** Permissions to manage networking resources (except firewall rules and SSL certificates).
  * **Security Admin Role:** Permissions to manage firewall rules and SSL certificates.

**1. Verify Current Permissions (on `test-vm`)**

  * The `test-vm` initially uses the Compute Engine default service account.
  * In the SSH terminal of `test-vm`:
      * Try to list firewall rules:
        ```bash
        gcloud compute firewall-rules list
        ```
        *Expected output: `ERROR: (gcloud.compute.firewall-rules.list) Some requests did not succeed: - Insufficient Permission`*
      * Try to delete a firewall rule (e.g., `allow-http-web-server` if it exists):
        ```bash
        gcloud compute firewall-rules delete allow-http-web-server
        ```
        *Expected output: `ERROR: (gcloud.compute.firewall-rules.delete) Could not fetch resource: - Insufficient Permission`*
        *(The default service account lacks these permissions).*

**2. Create a Service Account (`Network-admin`)**

  * In the Cloud Console, navigate to **IAM & admin \> Service Accounts**.
  * Click **Create service account**.
  * **Service account name:** `Network-admin`
  * Click **CREATE AND CONTINUE**.
  * **Grant access:**
      * **Select a role:** `Compute Engine` \> `Compute Network Admin`.
  * Click **CONTINUE**, then **DONE**.
  * **Create and download a JSON key:**
    1.  For the `Network-admin` service account, click the three dots (Actions) \> **Manage keys**.
    2.  Click **ADD KEY** \> **Create new key**.
    3.  Choose **JSON** as the key type and click **CREATE**.
    4.  The JSON key file will download. Rename it to `credentials.json`.

**3. Authorize `test-vm` with `Network-admin` Service Account and Verify Permissions**

  * In the SSH terminal of `test-vm`:
    1.  Upload `credentials.json` to the `test-vm` (usually via an upload button in the SSH client window).
    2.  Activate the service account:
        ```bash
        gcloud auth activate-service-account --key-file credentials.json
        ```
    3.  Try to list firewall rules again:
        ```bash
        gcloud compute firewall-rules list
        ```
        *Expected output: A list of firewall rules (this should now work).*
    4.  Try to delete the `allow-http-web-server` firewall rule:
        ```bash
        gcloud compute firewall-rules delete allow-http-web-server
        ```
        (Enter `Y` if prompted)
        *Expected output: `ERROR: (gcloud.compute.firewall-rules.delete) Could not fetch resource: - Required 'compute.firewalls.delete' permission...` (or similar insufficient permission error).*
        *(The Network Admin role can list but not delete firewall rules).*

**Lab Question (Example): The Network Admin role provides permissions to:**

  * **Correct Answer (based on lab behavior): List the available firewall rules.** (It cannot create, modify, or delete them).

**4. Update Service Account to `Security Admin` and Verify Permissions**

  * In the Cloud Console, navigate to **IAM & admin \> IAM**.
  * Find the `Network-admin` service account principal.
  * Click the pencil icon (Edit principal) for this account.
  * Change the role from `Compute Network Admin` to `Compute Engine` \> `Compute Security Admin`.
  * Click **SAVE**.
  * Return to the SSH terminal of `test-vm`. (The new permissions might take a short time to propagate).
      * Try to list firewall rules:
        ```bash
        gcloud compute firewall-rules list
        ```
        *Expected output: A list of firewall rules.*
      * Try to delete the `allow-http-web-server` firewall rule again:
        ```bash
        gcloud compute firewall-rules delete allow-http-web-server
        ```
        (Enter `Y` if prompted)
        *Expected output: `Deleted [https://www.googleapis.com/compute/v1/projects/.../global/firewalls/allow-http-web-server].` (This should now work).*
        *(The Security Admin role has permissions to list and delete firewall rules).*

**Lab Question (Example): The Security Admin role provides permissions to:**

  * **Correct Answers (based on lab behavior): List the available firewall rules, Delete the available firewall rules, Modify the available firewall rules, Create firewall rules.**

**5. Verify the Deletion of the Firewall Rule**

  * In the SSH terminal of `test-vm`:
      * Attempt to curl the `blue` server's external IP again:
        ```bash
        curl <BLUE_SERVER_EXTERNAL_IP>
        ```
        *Expected output: The request should hang or fail (CTRL+C to stop), as the `allow-http-web-server` rule that permitted this traffic has been deleted.*

This concludes the main tasks of the lab, demonstrating how to control network access using tagged firewall rules and manage permissions with IAM roles and service accounts.