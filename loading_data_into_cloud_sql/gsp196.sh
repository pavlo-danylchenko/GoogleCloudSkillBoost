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
echo "                 Task 1. Prepare your environment"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "          Clone the Data Science on Google Cloud repository"
echo "----------------------------------------------------------------------"
git clone https://github.com/GoogleCloudPlatform/data-science-on-gcp/
cd data-science-on-gcp/03_sqlstudio
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=${PROJECT_ID}-ml

echo "----------------------------------------------------------------------"
echo "             Stage the file into Cloud Storage bucket"
echo "----------------------------------------------------------------------"
gsutil cp create_table.sql gs://$BUCKET/create_table.sql

echo "======================================================================"
echo "                 Task 2. Create a Cloud SQL instance"
echo "======================================================================"
gcloud sql instances create flights \
    --database-version=POSTGRES_13 --cpu=2 --memory=8GiB \
    --region=$REGION --root-password=Passw0rd

export ADDRESS=$(curl -s http://ipecho.net/plain)/32
gcloud sql instances patch flights --authorized-networks $ADDRESS --quiet

gcloud sql databases create bts --instance=flights

export SERVICE_ACCOUNT=$(gcloud sql instances describe flights --format="value(serviceAccountEmailAddress)")

gcloud storage buckets add-iam-policy-binding gs://$BUCKET \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.objectAdmin"

gcloud sql import sql flights gs://$BUCKET/create_table.sql \
    --database=bts \
    --quiet

echo "JOB is DONE!"