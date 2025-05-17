#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
REGION="us-central1"
NETWORK="default"
FIREWALL_RULE_NAME="allow-tcp-rule-852"
MACHINE_TYPE="e2-medium"
INSTANCE_TAG="http-server"
TEAM="dodo"

# Resource Names 
TEMPLATE_NAME="$TEAM-web-template"
MIG_NAME="$TEAM-web-mig"
MIG_BASE_INSTANCE_NAME="$TEAM-web-vm"
HEALTH_CHECK_NAME="$TEAM-http-hc"
BACKEND_SERVICE_NAME="$TEAM-web-backend"
URL_MAP_NAME="$TEAM-lb-map"
TARGET_PROXY_NAME="$TEAM-http-proxy"
STATIC_IP_NAME="$TEAM-lb-ip"
FORWARDING_RULE_NAME="$TEAM-http-fw-rule"

echo "[*] Creating HTTP Load Balancer setup..."

# 1. Create Startup Script
cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF

# 2. Create Regional Instance Template
echo "[*] Creating instance template..."
gcloud compute instance-templates create $TEMPLATE_NAME \
    --region=$REGION \
    --network=$NETWORK \
    --machine-type=$MACHINE_TYPE \
    --metadata-from-file=startup-script=startup.sh \
    --tags=$INSTANCE_TAG || {
    echo "[!] Error: Failed to create instance template"
    exit 1
}

# 3. Create Regional Managed Instance Group
echo "[*] Creating managed instance group..."
gcloud compute instance-groups managed create $MIG_NAME \
    --base-instance-name=$MIG_BASE_INSTANCE_NAME \
    --size=2 \
    --template=$TEMPLATE_NAME \
    --region=$REGION || {
    echo "[!] Error: Failed to create managed instance group"
    exit 1
}

# 4. Create Firewall Rule
echo "[*] Creating firewall rule..."
gcloud compute firewall-rules create $FIREWALL_RULE_NAME \
    --network=$NETWORK \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=$INSTANCE_TAG || {
    echo "[!] Error: Failed to create firewall rule"
    exit 1
}

# 5. Create Health Check
echo "[*] Creating health check..."
gcloud compute http-health-checks create $HEALTH_CHECK_NAME \
    --port=80 || {
    echo "[!] Error: Failed to create health check"
    exit 1
}

# 6. Set Named Ports
echo "[*] Setting named ports..."
gcloud compute instance-groups managed set-named-ports $MIG_NAME \
    --named-ports=http:80 \
    --region=$REGION || {
    echo "[!] Error: Failed to set named ports"
    exit 1
}

# 7. Create Backend Service
echo "[*] Creating backend service..."
gcloud compute backend-services create $BACKEND_SERVICE_NAME \
    --protocol=HTTP \
    --port-name=http \
    --http-health-checks=$HEALTH_CHECK_NAME \
    --global || {
    echo "[!] Error: Failed to create backend service"
    exit 1
}

# 8. Add Instance Group to Backend Service
echo "[*] Adding instance group to backend service..."
gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME \
    --instance-group=$MIG_NAME \
    --instance-group-region=$REGION \
    --balancing-mode=UTILIZATION \
    --max-utilization=0.8 \
    --global || {
    echo "[!] Error: Failed to add instance group to backend service"
    exit 1
}

# 9. Create URL Map
echo "[*] Creating URL map..."
gcloud compute url-maps create $URL_MAP_NAME \
    --default-service=$BACKEND_SERVICE_NAME || {
    echo "[!] Error: Failed to create URL map"
    exit 1
}

# 10. Create Target HTTP Proxy
echo "[*] Creating target HTTP proxy..."
gcloud compute target-http-proxies create $TARGET_PROXY_NAME \
    --url-map=$URL_MAP_NAME || {
    echo "[!] Error: Failed to create target HTTP proxy"
    exit 1
}

# 11. Reserve Static IP
echo "[*] Reserving static IP..."
gcloud compute addresses create $STATIC_IP_NAME \
    --ip-version=IPV4 \
    --global || echo "[*] Static IP may already exist"

# Get the IP address
LOAD_BALANCER_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --global --format='value(address)') || {
    echo "[!] Error: Failed to get load balancer IP"
    exit 1
}

# 12. Create Forwarding Rule
echo "[*] Creating forwarding rule..."
gcloud compute forwarding-rules create $FORWARDING_RULE_NAME \
    --address=$LOAD_BALANCER_IP \
    --global \
    --target-http-proxy=$TARGET_PROXY_NAME \
    --ports=80 || echo "[*] Forwarding rule may already exist"

# Cleanup
rm startup.sh

echo "[=] Setup Complete!"
echo "[*] Load Balancer IP: $LOAD_BALANCER_IP"
echo "[*] Access your site at: http://$LOAD_BALANCER_IP"
echo "[*] Note: It may take a few minutes for the setup to become fully operational." 