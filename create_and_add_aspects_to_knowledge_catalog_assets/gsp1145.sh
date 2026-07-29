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
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                        Task 1. Create a lake"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                         Create a lake"
echo "----------------------------------------------------------------------"
gcloud dataplex lakes create orders-lake \
   --location=$REGION \
   --display-name="Orders Lake" \
   --description="Orders Domain"

echo "----------------------------------------------------------------------"
echo "                      Add a zone to the lake"
echo "----------------------------------------------------------------------"
gcloud dataplex zones create customer-curated-zone \
    --location=$REGION \
    --lake=orders-lake \
    --display-name="Customer Curated Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=CURATED \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "----------------------------------------------------------------------"
echo "                     Attach an asset to a zone"
echo "----------------------------------------------------------------------"
gcloud dataplex assets create customer-details-dataset \
    --location=$REGION \
    --lake=orders-lake \
    --zone=customer-curated-zone \
    --display-name="Customer Details Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customers \
    --discovery-enabled


echo "======================================================================"
echo "                     Task 2. Create an aspect type"
echo "======================================================================"
cat > protected-data-aspect.json << EOF
{
  "displayName": "Protected Data Aspect",
  "metadataTemplate": {
    "name": "protected_data_aspect",
    "type": "record",
    "recordFields": [
      {
        "name": "protected_data_flag",
        "index": 1,
        "type": "enum",
        "annotations": {
          "displayName": "Protected Data Flag"
        },
        "constraints": {
          "required": true
        },
        "enumValues": [
          {
            "name": "YES",
            "index": 1,
            "annotations": {
              "displayName": "Yes"
            }
          },
          {
            "name": "NO",
            "index": 2,
            "annotations": {
              "displayName": "No"
            }
          }
        ]
      }
    ]
  }
}
EOF

gcloud dataplex aspect-types create protected-data-aspect \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --file=protected-data-aspect.json

echo "======================================================================"
echo "                   Task 3. Add an aspect to assets"
echo "======================================================================"
echo "Perform Task #3 manually..."