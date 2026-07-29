#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable dataplex.googleapis.com
gcloud services enable datacatalog.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                        Task 1. Create a lake"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                         Create a lake"
echo "----------------------------------------------------------------------"
gcloud dataplex lakes create customer-info-lake \
   --location=$REGION \
   --display-name="Customer Info Lake"

echo "----------------------------------------------------------------------"
echo "                      Add a zone to the lake"
echo "----------------------------------------------------------------------"
gcloud dataplex zones create customer-raw-zone \
    --location=$REGION \
    --lake=customer-info-lake \
    --display-name="Customer Raw Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "----------------------------------------------------------------------"
echo "                     Attach an asset to a zone"
echo "----------------------------------------------------------------------"
gcloud dataplex assets create customer-online-sessions \
    --location=$REGION \
    --lake=customer-info-lake \
    --zone=customer-raw-zone \
    --display-name="Customer Online Sessions" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-bucket \
    --discovery-enabled


echo "======================================================================"
echo "                     Task 2. Create an aspect type"
echo "======================================================================"
echo "Perform Task #2-5 manually..."
echo "Click here: https://console.cloud.google.com/dataplex/secure?resourceName=projects%2F$DEVSHELL_PROJECT_ID%2Flocations%2F$REGION%2Flakes%2Fcustomer-info-lake&project=$DEVSHELL_PROJECT_ID"
