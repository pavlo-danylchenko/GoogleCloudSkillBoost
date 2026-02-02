#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 1. Viewing networks"
echo "======================================================================"
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")
gcloud config set compute/region $REGION

export ZONE=$(gcloud compute project-info desribe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
gcloud config set compute/zone $ZONE

gcloud compute instances create gcelab \
    --region=$REGION \
    --zone=$ZONE \
    --tags=http-server

echo "======================================================================"
echo "                   Task 2. Install an NGINX web server"
echo "======================================================================"
gcloud compute ssh gcelab --zone=$ZONE --quiet \
    --command="sudo apt-get update && sudo apt-get install -y nginx \
    && ps auwx | grep nginx"

echo "======================================================================"
echo "                   Task 3. Create a new instance with gcloud"
echo "======================================================================"
gcloud compute instances create gcelab2 \
    --machine-type=e2-medium --zone=$ZONE

gcloud compute ssh gcelab2 --zone=$ZONE --quiet \
    --command="exit"

echo "JOB IS DONE !"