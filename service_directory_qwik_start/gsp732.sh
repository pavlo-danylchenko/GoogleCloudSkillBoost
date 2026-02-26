#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE


echo "======================================================================"
echo "             Task 1. Configuring Service Directory"
echo "======================================================================"
# 1. Enable the Service Directory API
gcloud services enable servicedirectory.googleapis.com
sleep 10
# 2. Create the Namespace
gcloud service-directory namespaces create example-namespace \
    --location=$REGION
# 3. Create the Service
gcloud service-directory services create example-service \
    --namespace=example-namespace \
    --location=$REGION
# 4. Create the Endpoint
gcloud service-directory endpoints create example-endpoint \
    --service=example-service \
    --namespace=example-namespace \
    --location=$REGION \
    --address=0.0.0.0 \
    --port=80


echo "======================================================================"
echo "             Task 2. Configuring a Service Directory DNS zone"
echo "======================================================================"
gcloud dns managed-zones create example-zone-name \
    --description="Service Directory DNS zone" \
    --dns-name="myzone.example.com" \
    --visibility=private \
    --networks=default \
    --service-directory-namespace="https://servicedirectory.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/locations/$REGION/namespaces/example-namespace"

echo "JOB is DONE!"