# Cloud Security Fundamentals Challenge Lab

## Overview
This challenge lab tests your ability to implement security best practices in Google Cloud Platform (GCP). You'll create a secure Kubernetes Engine cluster with proper IAM roles and service accounts.

## Prerequisites
- Google Cloud SDK installed and configured
- Access to a GCP project with necessary permissions
- Basic knowledge of Kubernetes and GCP services

## Configuration Values
Before starting, you need to set these values:

```bash
# Basic GCP Configuration
PROJECT_ID="$GOOGLE_CLOUD_PROJECT"  # Your GCP project ID
ZONE="us-central1-c"               # e.g., us-central1-a
REGION="us-central1"               # e.g., us-central1

# Set default compute zone and region
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# Challenge-specific Configuration
CUSTOM_ROLE_NAME="orca_storage_editor_448"        # Name of the custom security role
SERVICE_ACCOUNT_NAME="orca-private-cluster-442-sa" # Name of the service account
CLUSTER_NAME="orca-cluster-282"                   # Name of the GKE cluster
SUBNET_NAME="orca-build-subnet"                   # Name of the subnet for the cluster
JUMPHOST_NAME="orca-jumphost"                     # Name of the jumphost instance
```

## Challenge Tasks

### Task 1: Create a Custom Security Role
Create a custom IAM role named `$CUSTOM_ROLE_NAME` with the following permissions:
- storage.buckets.get
- storage.objects.get
- storage.objects.list
- storage.objects.update
- storage.objects.create

```bash
gcloud iam roles create $CUSTOM_ROLE_NAME \
    --project=$PROJECT_ID \
    --permissions=storage.buckets.get,storage.objects.get,storage.objects.list,storage.objects.update,storage.objects.create \
    --title="Orca Storage Role"
```

### Task 2: Create a Service Account
Create a service account named `$SERVICE_ACCOUNT_NAME` that will be used by the GKE cluster:

```bash
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Orca Cluster Service Account"
```

### Task 3: Bind Roles to Service Account
Bind the following roles to the service account:
- Built-in roles:
  - roles/monitoring.viewer
  - roles/monitoring.metricWriter
  - roles/logging.logWriter
- Custom role: $CUSTOM_ROLE_NAME

```bash
# Bind built-in roles
for role in "roles/monitoring.viewer" "roles/monitoring.metricWriter" "roles/logging.logWriter"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="$role"
done

# Bind custom role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="projects/$PROJECT_ID/roles/$CUSTOM_ROLE_NAME"
```

### Task 4: Create Subnet and Jumphost
First, create a subnet for the cluster:

```bash
gcloud compute networks subnets create $SUBNET_NAME \
    --network=default \
    --enable-private-ip-google-access \
    --range=10.0.0.0/24 \
    --region=$REGION \
    --secondary-range=my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14
```

Then create a jumphost instance:

```bash
gcloud compute instances create $JUMPHOST_NAME \
    --zone=$ZONE \
    --scopes="https://www.googleapis.com/auth/cloud-platform"
```

### Task 5: Create Private GKE Cluster
Create a private GKE cluster with the following specifications:
- Name: $CLUSTER_NAME
- Subnet: $SUBNET_NAME
- Private nodes enabled
- Private endpoint enabled
- IP alias enabled
- Master authorized networks: $JUMPHOST_NAME internal IP

```bash
# Get jumphost IP
JUMPHOST_INTERNAL_IP=$(gcloud compute instances describe $JUMPHOST_NAME \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].networkIP)')

# Create cluster
gcloud beta container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --subnetwork=$SUBNET_NAME \
    --master-ipv4-cidr 172.16.0.32/28 \
    --enable-private-nodes \
    --enable-private-endpoint \
    --enable-ip-alias \
    --enable-master-authorized-networks \
    --master-authorized-networks=$JUMPHOST_INTERNAL_IP/32
```

### Task 6: Deploy Application via Jumphost
Deploy a test application through the jumphost:

```bash
# SSH into jumphost and run deployment commands
gcloud compute ssh $JUMPHOST_NAME --zone=$ZONE --command="
    # Install GKE auth plugin
    sudo apt-get update && sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin

    # Configure auth plugin
    if ! grep -q 'USE_GKE_GCLOUD_AUTH_PLUGIN=True' ~/.bashrc; then
        echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> ~/.bashrc
        source ~/.bashrc
    fi

    # Get cluster credentials
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --zone=$ZONE \
        --internal-ip

    # Deploy test application
    kubectl create deployment hello-server \
        --image=gcr.io/google-samples/hello-app:1.0

    # Create service
    kubectl expose deployment hello-server \
        --type=LoadBalancer \
        --port=8080
"
```

## Verification Steps
1. Verify the custom role was created:
```bash
gcloud iam roles describe $CUSTOM_ROLE_NAME --project=$PROJECT_ID
```

2. Verify the service account exists:
```bash
gcloud iam service-accounts describe $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com
```

3. Verify the cluster is running:
```bash
gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE
```

4. Verify the application deployment:
```bash
kubectl get deployment hello-server
kubectl get service hello-server
```

## Important Notes
- All resources should have the "orca-" prefix
- The cluster must be private with both private nodes and private endpoint
- Master authorized networks should only include the jumphost's internal IP
- The service account should have the minimum required permissions
- Use internal IP when getting cluster credentials
- The subnet must have secondary ranges for services and pods
- The cluster must use beta features for advanced networking

## Troubleshooting
If you encounter issues:
1. Check that all required APIs are enabled
2. Verify your IAM permissions
3. Ensure the jumphost exists and is accessible
4. Check that the subnet exists and is properly configured
5. Verify the service account has all required roles
6. Ensure you're using the beta version of the container clusters command
7. Verify the secondary ranges are properly configured in the subnet
