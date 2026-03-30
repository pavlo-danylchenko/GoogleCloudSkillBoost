#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable  dataplex.googleapis.com 

export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create a lake"
echo "======================================================================"
gcloud dataplex lakes create ecommerce \
   --location=$REGION \
   --display-name="Ecommerce" \
   --description="Ecommerce Domain"


echo "======================================================================"
echo "                    Task 2. Add a zone to your lake"
echo "======================================================================"
gcloud dataplex zones create orders-curated-zone \
    --location=$REGION \
    --lake=ecommerce \
    --display-name="Orders Curated Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=CURATED \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "======================================================================"
echo "                    Task 3. Attach an asset to a zone"
echo "======================================================================"
bq mk --location=$REGION --dataset orders

gcloud dataplex assets create orders-curated-dataset \
    --location=$REGION \
    --lake=ecommerce \
    --zone=orders-curated-zone \
    --display-name="Orders Curated Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$PROJECT_ID/datasets/orders \
    --discovery-enabled 


read -p "Check the progress to verify the objective and Press [Enter] key to continue..."

echo "======================================================================"
echo "                   Task 4. Delete assets, zones, and lakes"
echo "======================================================================"
gcloud dataplex assets delete orders-curated-dataset --location=$REGION --zone=orders-curated-zone --lake=ecommerce --quiet

gcloud dataplex zones delete orders-curated-zone --location=$REGION --lake=ecommerce --quiet

gcloud dataplex lakes delete ecommerce --location=$REGION --quiet 

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"