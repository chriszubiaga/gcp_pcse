# Securing Compute Engine Applications with IAP 

## Overview

This lab demonstrates how to secure web applications running on Compute Engine virtual machines using Identity-Aware Proxy (IAP). You will deploy a web-based IDE, configure an HTTPS Load Balancer for it, and then restrict access using IAP, applying Zero Trust principles where access is granted based on verified identity rather than network location. While the lab title mentions "Chrome Enterprise Premium," the core focus is on IAP for securing HTTP/HTTPS applications.

## What You’ll Do

* Configure an OAuth Consent screen.
* Set up OAuth access credentials (implicitly through IAP setup).
* Create a Compute Engine instance template with a startup script to deploy a web application.
* Create a managed instance group (MIG) and a health check.
* Generate a self-signed SSL certificate and create a Google Cloud SSL certificate resource.
* Configure a global external Application Load Balancer (HTTPS) with the MIG as a backend.
* Enable IAP for the load balancer's backend service.
* Restrict access to the application by granting specific users the IAP-secured Web App User role.
* Test IAP protection.

## Setup

* Standard Google Cloud lab environment.
* Cloud Shell will be used for `gcloud` commands and OpenSSL.

## Task 1: Create a Compute Engine Instance Template

The instance template will define the configuration for the VMs that will run your web application.

* **Key Configurations:**
    * **Series:** E2
    * **Machine Type:** `e2-micro`
    * **Access scopes:** `Compute Engine: Read Only` (The startup script uses `gcloud`, so it might need more, or the default service account on GCE has sufficient permissions for the `gcloud` commands in the script). The lab specifies "Set access for each API", implying default scopes might be modified. The `gcloud compute describe` and `gcloud config get-value` in the script might need `cloud-platform` scope or specific read scopes for compute and project configuration. Let's assume default service account scopes are sufficient for the script's `gcloud` commands.
    * **Firewall (VM-level tags/checkboxes):** Allow HTTP and HTTPS traffic (e.g., by applying tags like `http-server`, `https-server` which will be targeted by VPC firewall rules, or by checking the "Allow HTTP/HTTPS traffic" boxes which create default rules).
    * **Startup Script:** A provided script that:
        1.  Installs `git`, `virtualenv`.
        2.  Clones a Python sample application (`python-docs-samples/iap`).
        3.  Sets up a virtual environment and installs dependencies.
        4.  Dynamically configures the application (`real_backend.py`) by inserting the Backend Service ID and Project ID using `gcloud` commands executed *at instance startup*.
        5.  Starts the application using `gunicorn` on port 80.

* **gcloud CLI (Conceptual - Startup script makes direct `gcloud instance-templates create` complex):**
    Creating an instance template with a large, dynamic startup script is usually done by saving the script to a file and referencing it, or pasting it in the console.
    ```bash
    # 1. Save the provided startup script to a local file, e.g., startup-script.sh
    #    Ensure the script has execute permissions if needed: chmod +x startup-script.sh

    # 2. Create the instance template
    gcloud compute instance-templates create my-instance-template \
        --machine-type=e2-micro \
        --scopes=[https://www.googleapis.com/auth/compute.readonly,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append](https://www.googleapis.com/auth/compute.readonly,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append) `# Default scopes for e2-micro often include these. Add cloud-platform for gcloud in script if needed.` \
        --tags=http-server,https-server `# For VPC firewall rules` \
        --metadata-from-file=startup-script=startup-script.sh 
        # Or --metadata startup-script="$(< startup-script.sh)"
    ```
    *Note: The startup script's embedded `gcloud` commands (`gcloud compute backend-services describe...` and `gcloud config get-value project`) will run on the VM when it boots. This means the `my-backend-service` must exist and be discoverable by the time these VMs fully start and run that part of the script.*

## Task 2: Create a Health Check

Health checks are used by the load balancer and MIG to determine instance health.

* **Configuration:**
    * **Name:** `my-health-check`
    * **Protocol:** HTTP
    * **Port:** 80 (as Gunicorn in the startup script binds to `0.0.0.0:80`)
* **gcloud CLI command:**
    ```bash
    gcloud compute health-checks create http my-health-check \
        --port=80 \
        --check-interval=30s \
        --timeout=10s \
        --unhealthy-threshold=3 \
        --healthy-threshold=2
    ```

## Task 3: Create a Managed Instance Group (MIG)

The MIG will use the instance template to create and manage the application VMs.

* **Configuration:**
    * **Name:** `my-managed-instance-group`
    * **Instance template:** The template created in Task 1 (e.g., `my-instance-template`)
    * **Location:** Multiple zones (select a `REGION`)
    * **Autoscaling mode:** Off (Number of instances set manually, e.g., 2)
    * **Autohealing Health Check:** `my-health-check`
* **gcloud CLI command:**
    ```bash
    # Replace REGION with your target region, and INSTANCE_TEMPLATE_NAME with the name from Task 1
    # Replace NUMBER_OF_INSTANCES with desired count, e.g., 2
    gcloud compute instance-groups managed create my-managed-instance-group \
        --template=INSTANCE_TEMPLATE_NAME \
        --size=NUMBER_OF_INSTANCES \
        --region=REGION \
        --health-check=my-health-check \
        --initial-delay=300 # Seconds to wait before marking an instance unhealthy after it's created/restarted
    ```

## Task 4: Get a Domain Name and Certificate

This task involves creating a self-signed SSL certificate for the HTTPS load balancer. For production, you would use a CA-signed certificate.

**Part 1 - Create a Private Key and Certificate (using OpenSSL in Cloud Shell)**

1.  **Create a private key:**
    ```bash
    openssl genrsa -out my-private-key.key 2048
    ```
2.  **Create an OpenSSL configuration file (`ssl_config`):**
    * Use `vi ssl_config` or `nano ssl_config` to create this file with the content provided in the lab:
        ```ini
        [req]
        default_bits = 2048
        req_extensions = extension_requirements
        distinguished_name = dn_requirements
        prompt = no

        [extension_requirements]
        basicConstraints = CA:FALSE
        keyUsage = nonRepudiation, digitalSignature, keyEncipherment
        subjectAltName = @alt_names # Added for SAN

        [dn_requirements]
        countryName = US
        stateOrProvinceName = CA
        localityName = Mountain View
        0.organizationName = Cloud
        organizationalUnitName = Example
        commonName = Test # Replace with your test FQDN if you have one, or use a placeholder

        [alt_names] # Added for SAN
        DNS.1 = Test # Replace with your test FQDN, same as commonName or another
        ```
    *Hint: The lab's `ssl_config` doesn't include `subjectAltName` by default, which is crucial. I've added a basic one. For real use with IAP and modern browsers, a proper SAN matching the domain IAP will use is important.*
3.  **Create a Certificate Signing Request (CSR):**
    ```bash
    openssl req -new -key my-private-key.key -out my-csr.csr -config ssl_config
    ```
4.  **Create a self-signed certificate:**
    ```bash
    openssl x509 -req \
        -signkey my-private-key.key \
        -in my-csr.csr \
        -out my-certificate.pem \
        -extfile ssl_config \
        -extensions extension_requirements \
        -days 365
    ```

**Part 2 - Create a Google Cloud Self-Managed SSL Certificate Resource**

* Upload the private key and certificate to Google Cloud.
* **gcloud CLI command:**
    ```bash
    gcloud compute ssl-certificates create my-cert \
        --certificate=my-certificate.pem \
        --private-key=my-private-key.key \
        --global
    ```

## Task 5: Create a Load Balancer

Configure a Global External Application Load Balancer to serve traffic over HTTPS.

* **Name:** `my-load-balancer`

**1. Backend Configuration:**

* **Create Backend Service:**
    * **Name:** `my-backend-service` (**This exact name is critical for the startup script**)
    * **Backend type:** Instance group
    * **Protocol:** HTTP (traffic from LB to backends)
    * **Named port:** `http` (conventionally for port 80)
    * **Instance group:** `my-managed-instance-group` (select the correct region)
    * **Port numbers:** `80`
    * **Balancing mode:** (e.g., `UTILIZATION`, target 0.8)
    * **Health Check:** `my-health-check`
    * **Cloud CDN:** Uncheck (disable)
* **gcloud CLI for Backend Service:**
    ```bash
    gcloud compute backend-services create my-backend-service \
        --protocol=HTTP \
        --port-name=http \
        --health-checks=my-health-check \
        --global
    
    gcloud compute backend-services add-backend my-backend-service \
        --instance-group=my-managed-instance-group \
        --instance-group-region=REGION \
        --balancing-mode=UTILIZATION \
        --max-utilization=0.8 \
        --global
    ```

**2. Frontend Configuration:**

* **Protocol:** HTTPS
* **IP Version:** IPv4 (or IPv6 if needed)
* **IP Address:** Create a new static global IP address (e.g., name it `lb-ip-static`).
* **Port:** 443
* **Certificate:** `my-cert` (the SSL certificate resource created in Task 4)
* **gcloud CLI for Frontend:**
    1.  Reserve Static IP:
        ```bash
        gcloud compute addresses create lb-ip-static --global
        ```
    2.  Create URL Map (simple, default to backend service):
        ```bash
        gcloud compute url-maps create my-lb-url-map \
            --default-service=my-backend-service \
            --global
        ```
    3.  Create Target HTTPS Proxy:
        ```bash
        gcloud compute target-https-proxies create my-https-proxy \
            --ssl-certificates=my-cert \
            --url-map=my-lb-url-map \
            --global
        ```
    4.  Create Global Forwarding Rule:
        ```bash
        gcloud compute forwarding-rules create my-https-forwarding-rule \
            --address=lb-ip-static \
            --target-https-proxy=my-https-proxy \
            --ports=443 \
            --global
        ```

**3. Review and Create Load Balancer** (UI step after defining components)

**4. Restart your VMs in the MIG**

*This is critical for the startup script to correctly pick up the backend service ID if it relies on the service being fully configured.*
* **gcloud CLI command:**
    ```bash
    gcloud compute instance-groups managed rolling-action restart my-managed-instance-group \
        --region=REGION \
        --max-unavailable=3 \
        --min-ready=0s # As per lab example, adjust as needed (e.g. --max-unavailable=100%)
    ```

## Task 6: Set up IAP

Secure the application by enabling IAP on the load balancer's backend service.

**1. Configure Your Firewall**

* The lab suggests deleting `default-allow-internal`. **Caution**: This is a broad rule; understand its implications before deleting in a real environment.
    ```bash
    # gcloud compute firewall-rules delete default-allow-internal --quiet # Be cautious
    ```
* Create a firewall rule to allow traffic from Google's health checkers and IAP (for HTTPS LB, IAP protection is at LB, backends need to allow LB/HC traffic). The lab snippet for `allow-iap-traffic` includes ports 80 and 78 and health check ranges. Port 78 seems specific to the application. **The typical IAP for HTTPS LB doesn't need VMs to allow IAP's external IP ranges; VMs need to allow LB/HC traffic.**
    * The firewall rule mentioned in the lab `allow-iap-traffic` with source ranges `130.211.0.0/22` and `35.191.0.0/16` (health check ranges) allowing `tcp:80, tcp:78` is for allowing the Load Balancer (acting as proxy) and health checkers to reach the backends.
    * **gcloud CLI (for allowing LB/HC to backends):**
        ```bash
        gcloud compute firewall-rules create allow-lb-and-health-checks \
            --network=default \
            --action=ALLOW \
            --direction=INGRESS \
            --rules=tcp:80,tcp:78 `# Port 78 needs to be confirmed by application` \
            --source-ranges=130.211.0.0/22,35.191.0.0/16 \
            --target-tags=http-server,https-server `# Assuming instances have these tags`
        ```

**2. Enable IAP API (if not already done)**
    ```bash
    gcloud services enable iap.googleapis.com
    ```

**3. Configure OAuth Consent Screen (UI-driven)**
    * Follow lab steps: Navigate to **APIs & Services > OAuth consent screen**.
    * User Type: **External**.
    * Provide App name (e.g., "IAP Protected App"), User support email, Developer contact information.
    * Save and continue through other sections.

**4. Enable IAP for the Backend Service**
    * In the Cloud Console, navigate to **Security > Identity-Aware Proxy**.
    * Find the `my-backend-service` associated with your load balancer.
    * Toggle the switch in the **IAP** column to **ON**.
    * Confirm the OAuth configuration and turn on IAP.

**5. Add Principals to the IAP Access List**
    * On the Identity-Aware Proxy page, select `my-backend-service`.
    * Click **ADD PRINCIPAL** (or "Grant Access" in newer UIs).
    * **New Principals:** Your Qwiklabs student email.
    * **Role:** `Cloud IAP > IAP-secured Web App User` ( `roles/iap.securedWebAppUser` ).
    * Click **SAVE**.
* **gcloud CLI command to add IAP IAM policy binding:**
    ```bash
    # Replace YOUR_QWIKLABS_EMAIL with your actual email
    # Ensure my-backend-service is a global backend service
    gcloud iap web add-iam-policy-binding \
        --resource-service=backend-services \
        --resource-id=my-backend-service \
        --member="user:YOUR_QWIKLABS_EMAIL" \
        --role="roles/iap.securedWebAppUser"
    ```
    *Note: For `gcloud iap web add-iam-policy-binding`, the resource ID for a global backend service is its name.*

## Task 7: Test IAP

1.  **Find the Load Balancer's External IP Address:**
    * Cloud Console: **Network Services > Load balancing > Frontends**.
    * **gcloud CLI:**
        ```bash
        gcloud compute addresses describe lb-ip-static --global --format="get(address)"
        # Or list forwarding rules
        # gcloud compute forwarding-rules list --global --filter="name~my-https" --format="get(IPAddress)"
        ```
2.  **Test with `curl`:**
    ```bash
    # Replace EXTERNAL_IP with the actual IP
    curl -kvi https://EXTERNAL_IP
    ```
    * `-k` to ignore self-signed certificate errors.
    * `-v` for verbose output.
    * `-i` to include headers.
    * **Expected Result:** You should see a `302 Found` redirect response, with a `Location` header pointing to `accounts.google.com/...`. This indicates IAP is intercepting the request for authentication.
3.  **Test in Browser:**
    * Navigate to `https://EXTERNAL_IP` in your browser.
    * You will see certificate warnings (due to self-signed cert). Proceed if your browser allows.
    * You should be redirected to the Google sign-in page.
    * After signing in with your authorized Qwiklabs account, you *should* be able to access the application. The lab notes say "you won’t be able to access the application itself" due to the self-signed cert, but typically after bypassing the warning, IAP would grant access if authorized. The key is seeing the IAP intervention.

## Key Concepts and Important Points

* **Identity-Aware Proxy (IAP) for Web Applications:**
    * Secures access to applications running on Compute Engine (via Load Balancers), App Engine, or GKE.
    * Enforces access control based on user identity (Google accounts, groups, service accounts) and context, not just network origin.
    * Traffic is routed through IAP after hitting the Load Balancer's frontend, before reaching the backend service.

* **Zero Trust Access:** IAP helps implement a Zero Trust model by verifying every user and request.

* **OAuth Consent Screen:**
    * Required for IAP. Configures how your application requests user consent for identity information.
    * Specifies application name, support email, and authorized domains.

* **HTTPS Load Balancer:**
    * Essential for IAP with web applications. IAP integrates with Google Cloud External HTTPS Load Balancers.
    * Requires an SSL certificate (self-signed for testing, CA-signed for production).
    * Components: Frontend (IP, port, certificate, target proxy), Target HTTPS Proxy (uses URL map, SSL cert), URL Map (routes to backend services), Backend Service (defines backends, health checks).

* **Instance Templates & Managed Instance Groups (MIGs):**
    * Used to create scalable and resilient backends for the load balancer.
    * Startup scripts can automate application deployment and configuration on VMs.
    * Health checks are vital for MIGs and load balancers to ensure traffic is only sent to healthy instances.

* **Firewall Rules for Load Balanced Backends:**
    * VM instances behind a load balancer must have VPC firewall rules allowing traffic from the Google Cloud health checkers (`130.211.0.0/22`, `35.191.0.0/16`) and the load balancer itself (also these same ranges for proxy-based LBs) on the application's serving port (e.g., HTTP/80).

* **IAM Role for IAP Access:**
    * Users/groups need the `roles/iap.securedWebAppUser` ("IAP-secured Web App User") role granted on the IAP-protected resource (e.g., the backend service) to be allowed access.

* **Startup Script Dynamics:**
    * The lab's startup script uses `gcloud` commands *within the script* to fetch runtime configuration (like backend service ID). This requires the VM's service account to have permissions for those `gcloud` commands and for the referenced resources (like `my-backend-service`) to exist when the script queries them. Restarting VMs after LB and backend service creation is often necessary to ensure these dynamic configurations apply correctly.

* **Self-Signed Certificates & Testing:**
    * Self-signed certificates will cause browser warnings. They are suitable for testing IAP's redirection and authentication flow but not for production. The `curl -k` option ignores these certificate errors.