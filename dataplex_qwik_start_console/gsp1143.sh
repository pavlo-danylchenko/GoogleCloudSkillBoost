#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable dataplex.googleapis.com 

# export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create a lake"
echo "======================================================================"
gcloud dataplex lakes create sensors \
   --location=$REGION \
   --display-name="Sensors" \
   --description="Sensors Domain"


echo "======================================================================"
echo "                    Task 2. Add a zone to your lake"
echo "======================================================================"
gcloud dataplex zones create temperature-raw-data \
    --location=$REGION \
    --lake=sensors \
    --display-name="temperature raw data" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "======================================================================"
echo "                    Task 3. Attach an asset to a zone"
echo "======================================================================"
gsutil mb -l $REGION gs://$DEVSHELL_PROJECT_ID


gcloud dataplex assets create measurements \
    --location=$REGION \
    --lake=sensors \
    --zone=temperature-raw-data \
    --display-name="measurements" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID \
    --discovery-enabled

# read -p "Check the progress to verify the objective and Press [Enter] key to continue..."

echo "======================================================================"
echo "                   Task 4. Delete assets, zones, and lakes"
echo "======================================================================"
gcloud dataplex assets delete measurements --location=$REGION --zone=temperature-raw-data --lake=sensors --quiet

gcloud dataplex zones delete temperature-raw-data --location=$REGION --lake=sensors --quiet

gcloud dataplex lakes delete sensors --location=$REGION --quiet

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"