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
echo "                Task 1. Create a lake with a raw zone"
echo "======================================================================"
gcloud dataplex lakes create customer-engagements \
   --location=$REGION \
   --display-name="Customer Engagements" \
   --description="Customer Engagements Domain"

echo "----------------------------------------------------------------------"
echo "                      Add a zone to the lake"
echo "----------------------------------------------------------------------"
gcloud dataplex zones create raw-event-data \
    --location=$REGION \
    --lake=customer-engagements \
    --display-name="Raw Event Data" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "======================================================================"
echo "     Task 2. Create and attach a Cloud Storage bucket to the zone"
echo "======================================================================"
gsutil mb -l $REGION gs://$DEVSHELL_PROJECT_ID

gcloud dataplex assets create raw-event-files \
    --location=$REGION \
    --lake=customer-engagements \
    --zone=raw-event-data \
    --display-name="Raw Event Files" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID \
    --discovery-enabled


echo "======================================================================"
echo "     Task 3. Create an aspect type and add the aspect to an asset"
echo "======================================================================"
cat > protected-data-aspect.json << EOF
{
  "name": "protected_raw_data_aspect",
  "type": "record",
  "recordFields": [
    {
      "name": "protected_raw_data_flag",
      "index": 1,
      "type": "enum",
      "annotations": {
        "displayName": "Protected Raw Data Flag"
      },
      "constraints": {
        "required": true
      },
      "enumValues": [
        {
          "name": "Y",
          "index": 1
        },
        {
          "name": "N",
          "index": 2
        }
      ]
    }
  ]
}
EOF

gcloud dataplex aspect-types create protected-raw-data-aspect \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="Protected Raw Data Aspect" \
    --metadata-template-file-name=protected-data-aspect.json

echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"