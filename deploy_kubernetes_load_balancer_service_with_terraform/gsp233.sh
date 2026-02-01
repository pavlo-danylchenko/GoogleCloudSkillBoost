#!/bin/bash
set -euo pipefail

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo "======================================================================"
echo "                     Task 1. Clone the sample code"
echo "======================================================================"
gsutil -m cp -r gs://spls/gsp233/* .
cd tf-gke-k8s-service-lb

echo "======================================================================"
echo "                     Task 2. Understand the code"
echo "======================================================================"
echo "======================================================================"
echo "               Task 3. Initialize and install dependencies"
echo "======================================================================"
terraform init
terraform apply -var="region=$REGION" -var="location=$ZONE" --auto-approve

echo "Job is Done!"