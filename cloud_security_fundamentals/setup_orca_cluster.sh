#!/bin/bash

# Exit on error
set -e

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "[!] Error: $1 is required but not installed."
        exit 1
    fi
}

# Check required commands
check_command gcloud
check_command kubectl

# =============================================
# MANUAL CONFIGURATION - EDIT THESE VALUES
# =============================================
# Replace these values with your actual values
PROJECT_ID="qwiklabs-gcp-00-6976134c3201"        # Your GCP project ID
ZONE="europe-west1-c"                    # e.g., us-central1-a
REGION="europe-west1"                # e.g., us-central1
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# Challenge-specific placeholders
CUSTOM_ROLE_NAME="orca_storage_editor_759"    # Name of the custom security role
SERVICE_ACCOUNT_NAME="orca-private-cluster-271-sa"  # Name of the service account
CLUSTER_NAME="orca-cluster-862"             # Name of the GKE cluster
SUBNET_NAME="orca-build-subnet"         # Name of the subnet for the cluster
JUMPHOST_NAME="orca-jumphost"           # Name of the jumphost instance
# =============================================

# Verify configuration
if [ "$PROJECT_ID" = "your-project-id" ] || [ "$ZONE" = "your-zone" ] || [ "$REGION" = "your-region" ]; then
    echo "[!] Error: Please edit the script and set your PROJECT_ID, ZONE, and REGION"
    exit 1
fi

echo "[*] Starting Orca cluster setup in project: $PROJECT_ID, zone: $ZONE"

# Task 1: Create Custom Security Role
echo "[*] Creating custom security role: $CUSTOM_ROLE_NAME"
gcloud iam roles create $CUSTOM_ROLE_NAME \
    --project=$PROJECT_ID \
    --permissions=storage.buckets.get,storage.objects.get,storage.objects.list,storage.objects.update,storage.objects.create \
    --title="Orca Storage Role" || {
    echo "[!] Error: Failed to create custom role"
    exit 1
}

# Task 2: Create Service Account
echo "[*] Creating service account: $SERVICE_ACCOUNT_NAME"
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Orca Cluster Service Account" || {
    echo "[!] Error: Failed to create service account"
    exit 1
}

# Task 3: Bind Roles to Service Account
echo "[*] Binding roles to service account"
# Built-in roles
for role in "roles/monitoring.viewer" "roles/monitoring.metricWriter" "roles/logging.logWriter"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="$role" || {
        echo "[!] Error: Failed to bind role $role"
        exit 1
    }
done

# Custom role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="projects/$PROJECT_ID/roles/$CUSTOM_ROLE_NAME" || {
    echo "[!] Error: Failed to bind custom role"
    exit 1
}

# --- if needed, should exist already
echo "[*] Creating jumphost instance: $JUMPHOST_NAME"
gcloud compute instances create $JUMPHOST_NAME \
    --zone=$ZONE \
    --network-interface=network="orca-build-vpc",subnet="orca-mgmt-subnet" \
    --scopes="https://www.googleapis.com/auth/cloud-platform" || {
    echo "[!] Error: Failed to create jumphost instance"
    exit 1
}

# Create subnet for the cluster
echo "[*] Creating subnet: $SUBNET_NAME"
gcloud compute networks subnets create $SUBNET_NAME \
    --network=default \
    --enable-private-ip-google-access \
    --range=10.0.0.0/24 \
    --region=$REGION  \
    --secondary-range=my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14 || {
    echo "[!] Error: Failed to create subnet"
    exit 1
}
# --- 

echo "[*] Getting jumphost IP"
JUMPHOST_INTERNAL_IP=$(gcloud compute instances describe $JUMPHOST_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].networkIP)') || {
    echo "[!] Error: Failed to get jumphost IP"
    exit 1
}

if [ -z "$JUMPHOST_INTERNAL_IP" ]; then
    echo "[!] Error: Jumphost IP is empty"
    exit 1
fi

# Task 4: Create GKE cluster
echo "[*] Creating private GKE cluster"
gcloud beta container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --network="orca-build-vpc" \
    --subnetwork=$SUBNET_NAME \
    --master-ipv4-cidr="172.16.0.32/28" \
    --enable-private-nodes \
    --enable-private-endpoint \
    --enable-ip-alias \
    --service-account="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --enable-master-authorized-networks \
    --master-authorized-networks=$JUMPHOST_INTERNAL_IP/32 || {
    echo "[!] Error: Failed to create GKE cluster"
    exit 1
}

# Task 5: Deploy Application via Jumphost
echo "[*] Deploying application via jumphost: $JUMPHOST_NAME"

# Create a heredoc with all commands to run on the jumphost
gcloud compute ssh $JUMPHOST_NAME --zone=$ZONE --command="
    echo '[*] Installing GKE auth plugin'
    sudo apt-get update && sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin || {
        echo '[!] Error: Failed to install GKE auth plugin'
        exit 1
    }

    # Add auth plugin configuration to bashrc if not already present
    if ! grep -q 'USE_GKE_GCLOUD_AUTH_PLUGIN=True' ~/.bashrc; then
        echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> ~/.bashrc
        source ~/.bashrc
    fi

    echo '[*] Getting cluster credentials'
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --internal-ip || {
        echo '[!] Error: Failed to get cluster credentials'
        exit 1
    }

    echo '[*] Deploying test application'
    kubectl create deployment hello-server \
        --image=gcr.io/google-samples/hello-app:1.0 || {
        echo '[!] Error: Failed to create deployment'
        exit 1
    }

    echo '[=] Deployment completed successfully!'
    echo '[*] To verify the deployment, run: kubectl get service hello-server'
" || {
    echo "[!] Error: Failed to deploy application via jumphost"
    exit 1
}

echo "[=] Setup completed successfully!" 