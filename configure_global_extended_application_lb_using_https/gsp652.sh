#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


read -p "Input the second ZONE: " ZONE_2
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)

echo "======================================================================"
echo "                  Task 1. Create Instance Groups"
echo "======================================================================"
# Replace [REGION_GROUP_NAME] with your group name (e.g., region-instance-group)
# Replace [ZONE] with your specific zone (e.g., us-central1-a)
gcloud compute instance-groups unmanaged create $REGION-instance-group \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID

gcloud compute instance-groups unmanaged create $REGION_2-instance-group \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID


gcloud compute instance-groups unmanaged add-instances $REGION-instance-group \
    --zone=$ZONE \
    --instances=backend-vm-$REGION

gcloud compute instance-groups unmanaged add-instances $REGION_2-instance-group \
    --zone=$ZONE_2 \
    --instances=backend-vm-$REGION_2


echo "======================================================================"
echo "                  Task 2. Create a health check"
echo "======================================================================"
gcloud compute health-checks create http http-health-check \
    --project=$DEVSHELL_PROJECT_ID \
    --port=80 \
    --request-path=/ \
    --check-interval=5s \
    --timeout=5s \
    --unhealthy-threshold=2 \
    --healthy-threshold=2 \
    --global


echo "======================================================================"
echo "                   Task 3. Create a backend service"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                        Create a Certificate"
echo "----------------------------------------------------------------------"
# Generate the private key and certificate
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 365 \
    -subj "/CN=example.com"

# Create the SSL certificate resource in GCP
gcloud compute ssl-certificates create self-signed-lb-cert \
    --certificate=cert.pem \
    --private-key=key.pem \
    --global

# Create the backend service
gcloud compute backend-services create global-backend-service \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-health-check \
    --global

# Add the first instance group (Region)
gcloud compute backend-services add-backend global-backend-service \
    --instance-group=$REGION-instance-group \
    --instance-group-zone=$ZONE \
    --global

# Add the second instance group (Region2)
gcloud compute backend-services add-backend global-backend-service \
    --instance-group=$REGION_2-instance-group \
    --instance-group-zone=$ZONE_2 \
    --global

# Create the URL map
gcloud compute url-maps create global-ext-application-lb \
    --default-service=global-backend-service

# Reserve a global static IP
gcloud compute addresses create global-lb-ip --global

# Create the Target HTTPS Proxy
gcloud compute target-https-proxies create https-lb-proxy \
    --url-map=global-ext-application-lb \
    --ssl-certificates=self-signed-lb-cert

# Create the Global Forwarding Rule (Frontend)
gcloud compute forwarding-rules create https-frontend \
    --address=global-lb-ip \
    --target-https-proxy=https-lb-proxy \
    --global \
    --ports=443


# Create the URL map for redirection
cat <<EOF > redirect.yaml
kind: compute#urlMap
name: http-to-https-redirect
defaultUrlRedirect:
  redirectResponseCode: MOVED_PERMANENTLY_DEFAULT
  httpsRedirect: true
EOF

gcloud compute url-maps import http-to-https-redirect \
    --source=redirect.yaml --global

# Create HTTP Target Proxy
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map=http-to-https-redirect --global

# Create HTTP Forwarding Rule
gcloud compute forwarding-rules create http-frontend \
    --address=global-lb-ip \
    --target-http-proxy=http-lb-proxy \
    --global \
    --ports=80

