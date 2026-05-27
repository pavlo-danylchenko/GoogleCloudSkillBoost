#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"


read -p "Enter the REGION #1: " REGION_1
read -p "Enter the REGION #2: " REGION_2
read -p "Enter the REGION #3: " REGION_3

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "          Task 1. Create custom network with Cloud Shell"
echo "======================================================================"
gcloud compute networks create taw-custom-network \
    --subnet-mode=custom

gcloud compute networks subnets create subnet-$REGION_1 \
    --network=taw-custom-network \
    --region=$REGION_1 \
    --range=10.0.0.0/16

gcloud compute networks subnets create subnet-$REGION_2 \
    --network=taw-custom-network \
    --region=$REGION_2 \
    --range=10.1.0.0/16

gcloud compute networks subnets create subnet-$REGION_3 \
    --network=taw-custom-network \
    --region=$REGION_3 \
    --range=10.2.0.0/16


echo "======================================================================"
echo "                  Task 2. Add firewall rules"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                  Add firewall rules using Cloud Shell"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create nw101-allow-http \
    --network=taw-custom-network \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http

echo "----------------------------------------------------------------------"
echo "                  Create additional firewall rules"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create nw101-allow-icmp \
    --network=taw-custom-network \
    --allow=icmp \
    --target-tags=rules

gcloud compute firewall-rules create nw101-allow-internal \
    --network=taw-custom-network \
    --allow=tcp:0-65535,udp:0-65535,icmp \
    --source-ranges=10.0.0.0/16,10.1.0.0/16,10.2.0.0/16

gcloud compute firewall-rules create nw101-allow-ssh \
    --network=taw-custom-network \
    --allow=tcp:22 \
    --target-tags=ssh

gcloud compute firewall-rules create nw101-allow-rdp \
    --network=taw-custom-network \
    --allow=tcp:3389

echo "======================================================================"
echo "                         JOB is DONE!"
echo "=====================================================================