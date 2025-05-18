
# Build a Secure Google Cloud Network


![Diagram](.\assets\challenge.png)

**Assumptions:**

  * VPC Network Name: `acme-vpc`
  * Bastion's Subnet Name: `acme-mgmt-subnet`
  * Juice-Shop's Subnet Name: `acme-app-subnet`
  * Bastion VM Name: `bastion`
  * Juice-Shop VM Name: `juice-shop`
  * Region/Zone: $ZONE


```bash
# TAGS
export PROJECT_ID=qwiklabs-gcp-01-a94f59c7246b
export REGION=europe-west4
export ZONE=europe-west4-a
export SSH_IAP_TAG=grant-ssh-iap-ingress-ql-710
export HTTP_TAG=grant-http-ingress-ql-710
export SSH_INTERNAL_TAG=grant-ssh-internal-ingress-ql-710
```
-----

**Step 1: Check and Remove Overly Permissive Firewall Rules**

This step is crucial. Overly permissive rules (e.g., allowing SSH from `0.0.0.0/0` to all instances) must be removed or tightened.

  * **Action:** List existing firewall rules to identify them.
    ```bash
    gcloud compute firewall-rules list --filter="NETWORK:acme-vpc" --sort-by=NAME
    ```
  * **Identify:** Look for rules like `open-access` or any custom rule that allows SSH (tcp:22) from `0.0.0.0/0` or other broad ranges to instances that shouldn't have such access.
  * **Action:** Remove identified overly permissive rules.
    ```bash
    # Example: If you find a rule named 'open-access'
    gcloud compute firewall-rules delete open-access --quiet
    ```
    **UI Steps (if preferred for review and deletion):**
    1.  Navigate to **VPC network \> Firewall** in the Google Cloud Console.
    2.  Select the `acme-vpc`.
    3.  Review each rule. If a rule allows overly broad access (e.g., `Source IP ranges: 0.0.0.0/0` for SSH to all instances), select it and click **DELETE**.

-----

**Step 2: Configure Bastion Host**


  * **Action:** Start the bastion host instance if it was stopped.
    ```bash
    gcloud compute instances start bastion --zone=$ZONE
    ```
    **UI Steps:**
    1.  Navigate to **Compute Engine \> VM instances**.
    2.  Select the `bastion` VM.
    3.  Click **START**.

* Add Network Tag to Bastion Host for IAP SSH**

  * **Action:**
    ```bash
    gcloud compute instances add-tags bastion \
    --tags=$SSH_IAP_TAG \
    --zone=$ZONE 
    ```

**2.3. Create Firewall Rule for IAP SSH to Bastion**

This rule allows SSH (tcp/22) only from Google's IAP service IP range.

  * **Key Concept:** IAP uses the source IP range `35.235.240.0/20` for TCP forwarding.
  * **Action:**
    ```bash
    gcloud compute firewall-rules create allow-ssh-iap-to-bastion \
        --network=acme-vpc \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:22 \
        --source-ranges=35.235.240.0/20 \
        --target-tags=$SSH_IAP_TAG \
        --description="Allow SSH to bastion via IAP"
    ```

-----

**Step 3: Configure `juice-shop` Server**

**3.1. Add Network Tag to `juice-shop` for HTTP**

  * **Action:**
    ```bash
    gcloud compute instances add-tags juice-shop \
        --tags=$HTTP_TAG \
        --zone=$ZONE
    ```

**3.2. Create Firewall Rule for HTTP to `juice-shop`**

This rule allows HTTP (tcp/80) from any address to the `juice-shop` instance.

  * **Action:**
    ```bash
    gcloud compute firewall-rules create allow-http-to-juice-shop \
        --network=acme-vpc \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:80 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=$HTTP_TAG \
        --description="Allow HTTP to juice-shop from anywhere"
    ```

**3.3. Add Network Tag to `juice-shop` for Internal SSH**

  * **Action:**
    ```bash
    gcloud compute instances add-tags juice-shop \
        --tags=$SSH_INTERNAL_TAG \
        --zone=$ZONE
    ```

**3.4. Create Firewall Rule for Internal SSH to `juice-shop` from Bastion's Subnet**

This rule allows SSH (tcp/22) to `juice-shop` only from the `acme-mgmt-subnet`.
First, you need the IP range for `acme-mgmt-subnet`.

  * **Action (Get subnet IP range - if you don't know it):**

    ```bash
    gcloud compute networks subnets describe acme-mgmt-subnet \
        --region=$REGION \
        --format="get(ipCidrRange)" 
    ```

    Let's assume the output is `192.168.10.0/24`. Replace `BASTION_SUBNET_CIDR` with this value.

  * **Action:**

    ```bash
    # Replace BASTION_SUBNET_CIDR with the actual CIDR of acme-mgmt-subnet, e.g., 10.0.1.0/24
    gcloud compute firewall-rules create allow-ssh-internal-to-juice-shop \
        --network=acme-vpc \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:22 \
        --source-ranges=192.168.10.0/24 \
        --target-tags=$SSH_INTERNAL_TAG \
        --description="Allow SSH to juice-shop from bastion subnet"
    ```

-----

**Step 4: Test Connectivity**

**4.1. SSH to Bastion Host via IAP**

  * **Key Concept:** `gcloud compute ssh` with IAP automatically handles the IAP tunnel if the necessary permissions and firewall rules are in place. You typically don't specify `--tunnel-through-iap` anymore as it's often inferred if direct connection fails or no external IP exists. However, if it fails, troubleshooting might involve ensuring your user account has "IAP-secured Tunnel User" role on the bastion.

  * **Action:**

    ```bash
    gcloud compute ssh bastion \
        --zone=$ZONE \
        --project=qwiklabs-gcp-03-cf07d6a2e24e
    ```

    If you encounter issues, the `--troubleshoot` flag can be helpful:

    ```bash
    gcloud compute ssh bastion \
        --zone=$ZONE \
        --project=qwiklabs-gcp-03-cf07d6a2e24e \
        --troubleshoot
    ```

    **UI Steps (for IAP SSH):**

    1.  Navigate to **Compute Engine \> VM instances**.
    2.  Find the `bastion` instance.
    3.  In the **Connect** column, click the **SSH** dropdown and select **Open in browser window** (this often uses IAP). Alternatively, if `gcloud` is configured in your local Cloud SDK, the `gcloud compute ssh` command is preferred.

**4.2. From Bastion, SSH to `juice-shop`**

  * Once you are logged into the `bastion` via SSH:
  * **Action:**
    ```bash
    # Inside the bastion's SSH session
    ssh juice-shop # Or ssh <INTERNAL_IP_OF_JUICE_SHOP>
    ```
      * For this to work by name (`ssh juice-shop`), internal DNS resolution must be working correctly within your `acme-vpc`. If not, you'll need to use the internal IP address of `juice-shop`.
      * You can find the internal IP of `juice-shop` from the Cloud Console or using:
        ```bash
        # Run this on your local machine or Cloud Shell, not on the bastion
        gcloud compute instances describe juice-shop \
            --zone=$ZONE \
            --format='get(networkInterfaces[0].networkIP)'
        ```

-----
