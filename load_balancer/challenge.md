# HTTP Load Balancer

## Steps
1. **Instance Template Creation**
   - Create a regional instance template with desired machine type and startup script
   - Configure network settings and instance tags

2. **Managed Instance Group (MIG) Setup**
   - Create a regional MIG using the instance template
   - Set initial size and base instance name
   - Configure named ports for HTTP traffic

3. **Network Security Configuration**
   - Create firewall rules to allow HTTP traffic (port 80)
   - Apply rules to instances with specific tags

4. **Health Check Configuration**
   - Create HTTP health check to monitor instance health
   - Configure port and other health check parameters

5. **Backend Service Setup**
   - Create global backend service
   - Configure protocol and health checks
   - Add MIG as backend with load balancing settings

6. **Load Balancer Components**
   - Create URL map for routing rules
   - Set up target HTTP proxy
   - Reserve static IP address
   - Create global forwarding rule

7. **Verification and Testing**
   - Wait for instances to be healthy
   - Test load balancer access
   - Monitor instance group and load balancer status

## Sample

```bash
#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Default region based on user requirement
REGION="us-west3"
NETWORK="default"
# Specific firewall rule name from the original challenge description
# Ensure this name matches the exact requirement of your lab/task
FIREWALL_RULE_NAME="allow-tcp-rule-852"
# Specified machine type requirement for the template
MACHINE_TYPE="e2-medium"
# Tag for firewall rule targeting
INSTANCE_TAG="http-server"
# For naming convention
TEAM="dodo"

# Resource Names 
TEMPLATE_NAME="$TEAM-web-template"
MIG_NAME="$TEAM-web-mig" # Regional MIG
MIG_BASE_INSTANCE_NAME="$TEAM-web-vm"
HEALTH_CHECK_NAME="$TEAM-http-hc"
BACKEND_SERVICE_NAME="$TEAM-web-backend" # Global Backend Service
URL_MAP_NAME="$TEAM-lb-map"
TARGET_PROXY_NAME="$TEAM-http-proxy"
STATIC_IP_NAME="$TEAM-lb-ip"
FORWARDING_RULE_NAME="$TEAM-http-fw-rule"


echo "NOTE: Creating a Regional template and MIG in $REGION."

# 1. Create the Startup Script Locally
# This script configures Nginx on the instances
echo "Creating startup script (startup.sh)..."
cat << EOF > startup.sh
#! /bin/bash
# Updates package lists and installs nginx
apt-get update
apt-get install -y nginx
# Starts nginx service
service nginx start
# Modifies the default nginx page to include the VM's hostname
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF
echo "Startup script created."
echo ""

# 2. Create the Regional Instance Template
# Defines the configuration for VMs in the MIG. Created in the specified region.
echo "Creating REGIONAL instance template ($TEMPLATE_NAME) in $REGION on network '$NETWORK' with machine type $MACHINE_TYPE..."
gcloud compute instance-templates create $TEMPLATE_NAME \
    --region=$REGION \
    --network=$NETWORK \
    --machine-type=$MACHINE_TYPE \
    --metadata-from-file=startup-script=startup.sh \
    --tags=$INSTANCE_TAG
echo "Regional instance template created in $REGION."
echo ""

# 3. Create the Regional Managed Instance Group (MIG)
# Manages a group of identical VMs based on the regional template.
echo "Creating REGIONAL managed instance group ($MIG_NAME) in $REGION..."
gcloud compute instance-groups managed create $MIG_NAME \
    --base-instance-name=$MIG_BASE_INSTANCE_NAME \
    --size=2 \
    --template=$TEMPLATE_NAME \
    --region=$REGION
echo "Regional managed instance group created in $REGION."
echo ""

# 4. Create the Firewall Rule
# Allows incoming HTTP traffic to instances with the correct tag
# Firewall rules apply per-network.
echo "Creating firewall rule ($FIREWALL_RULE_NAME) on network '$NETWORK' to allow TCP port 80..."
gcloud compute firewall-rules create $FIREWALL_RULE_NAME \
    --network=$NETWORK \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=$INSTANCE_TAG
echo "Firewall rule created."
echo ""

# 5. Create the Health Check (Global)
# Used by the load balancer to check if instances are healthy
echo "Creating HTTP health check ($HEALTH_CHECK_NAME)..."
gcloud compute http-health-checks create $HEALTH_CHECK_NAME \
    --port=80
echo "Health check created."
echo ""

# 6. Set Named Ports on the Regional MIG
# Associates a name (http) with a port number (80) for the MIG
echo "Setting named port 'http:80' on Regional MIG ($MIG_NAME) in $REGION..."
gcloud compute instance-groups managed set-named-ports $MIG_NAME \
    --named-ports=http:80 \
    --region=$REGION
echo "Named port set."
echo ""

# 7. Create the Backend Service (Global)
# Defines how the load balancer distributes traffic to backends
echo "Creating global backend service ($BACKEND_SERVICE_NAME)..."
gcloud compute backend-services create $BACKEND_SERVICE_NAME \
    --protocol=HTTP \
    --port-name=http \
    --http-health-checks=$HEALTH_CHECK_NAME \
    --global
echo "Backend service created."
echo ""

# 8. Add the Regional Instance Group to the Backend Service
# Links the MIG to the backend service
echo "Adding Regional MIG ($MIG_NAME) from $REGION to global backend service ($BACKEND_SERVICE_NAME)..."
gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME \
    --instance-group=$MIG_NAME \
    --instance-group-region=$REGION \
    --balancing-mode=UTILIZATION \
    --max-utilization=0.8 \
    --global
echo "Instance group added to backend service."
echo ""

# 9. Create the URL Map (Global)
# Defines routing rules for incoming requests
echo "Creating URL map ($URL_MAP_NAME)..."
gcloud compute url-maps create $URL_MAP_NAME \
    --default-service=$BACKEND_SERVICE_NAME
echo "URL map created."
echo ""

# 10. Create the Target HTTP Proxy (Global)
# Receives requests and uses the URL map to route them
echo "Creating target HTTP proxy ($TARGET_PROXY_NAME)..."
gcloud compute target-http-proxies create $TARGET_PROXY_NAME \
    --url-map=$URL_MAP_NAME
echo "Target HTTP proxy created."
echo ""

# 11. Reserve a Static External IP Address (Global)
# Provides a stable IP address for the load balancer frontend
echo "Reserving global static IP address ($STATIC_IP_NAME)..."
# Error handling in case the address already exists
gcloud compute addresses create $STATIC_IP_NAME \
    --ip-version=IPV4 \
    --global || echo "Static IP address $STATIC_IP_NAME may already exist. Attempting to retrieve it."

# Retrieve the IP address regardless of whether creation succeeded or failed
LOAD_BALANCER_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --global --format='value(address)')
echo "Static IP address $LOAD_BALANCER_IP reserved/retrieved."
echo ""

# 12. Create the Global Forwarding Rule
# Connects the public IP address and port to the target proxy
echo "Creating global forwarding rule ($FORWARDING_RULE_NAME) using IP $LOAD_BALANCER_IP..."
# Error handling in case the forwarding rule already exists
gcloud compute forwarding-rules create $FORWARDING_RULE_NAME \
    --address=$LOAD_BALANCER_IP \
    --global \
    --target-http-proxy=$TARGET_PROXY_NAME \
    --ports=80 || echo "Forwarding rule $FORWARDING_RULE_NAME may already exist."
echo "Global forwarding rule created/verified."
echo ""

echo "--- Nucleus HTTP Load Balancer Setup Complete (Regional MIG/Template in $REGION) ---"
echo "Load Balancer IP Address: $LOAD_BALANCER_IP"
echo "It might take a few minutes for the setup to become fully operational and pass health checks."
echo "Instances in the Regional MIG will be provisioned in $REGION."
echo "You can check the status in the Google Cloud Console under Load Balancing and Instance Groups."
echo "Access the site via http://$LOAD_BALANCER_IP"

# Clean up the local startup script file
rm startup.sh