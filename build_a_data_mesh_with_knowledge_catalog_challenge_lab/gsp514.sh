#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable dataplex.googleapis.com \
    datacatalog.googleapis.com \
    dataproc.googleapis.com

read -p "Input the second USER: " USER_2

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "Task 1. Create a Knowledge Catalog lake with two zones and two assets"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                         Create a lake"
echo "----------------------------------------------------------------------"
gcloud dataplex lakes create sales-lake \
   --location=$REGION \
   --display-name="Sales Lake"

echo "----------------------------------------------------------------------"
echo "                      Add zones to the lake"
echo "----------------------------------------------------------------------"
gcloud dataplex zones create raw-customer-zone \
    --location=$REGION \
    --lake=sales-lake \
    --display-name="Raw Customer Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=RAW \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


gcloud dataplex zones create curated-customer-zone \
    --location=$REGION \
    --lake=sales-lake \
    --display-name="Curated Customer Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=CURATED \
    --discovery-enabled \
    --discovery-schedule="0 * * * *"


echo "----------------------------------------------------------------------"
echo "                     Attach an asset to a zone"
echo "----------------------------------------------------------------------"
gcloud dataplex assets create customer-engagements \
    --location=$REGION \
    --lake=sales-lake \
    --zone=raw-customer-zone \
    --display-name="Customer Engagements" \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-customer-online-sessions \
    --discovery-enabled

gcloud dataplex assets create customer-orders \
    --location=$REGION \
    --lake=sales-lake \
    --zone=curated-customer-zone \
    --display-name="Customer Orders" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders \
    --discovery-enabled


echo "======================================================================"
echo "       Task 2. Create an aspect type and add an aspect to a zone"
echo "======================================================================"
cat > protected-data-aspect.json << EOF
{
  "displayName": "Protected Customer Data Aspect",
  "metadataTemplate": {
    "name": "protected-customer-data-aspect",
    "type": "record",
    "recordFields": [
      {
        "name": "raw-data-flag",
        "index": 1,
        "type": "enum",
        "annotations": {
          "displayName": "Raw Data Flag"
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
      },
      {
        "name": "protected-contact-information-flag",
        "index": 2,
        "type": "enum",
        "annotations": {
          "displayName": "Protected Contact Information Flag"
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

gcloud dataplex aspect-types create protected-customer-data-aspect \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata-template-file-name=protected-data-aspect.json

echo "Add protected-customer-data-aspect to the Raw Customer Zone using a value of Yes for both flags manually."
read "Press [ENTER] to continue..."


echo "======================================================================"
echo "     Task 3. Assign a Knowledge Catalog IAM role to another user"
echo "======================================================================"
gcloud dataplex assets add-iam-policy-binding customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --member=user:$USER_2 \
  --role=roles/dataplex.dataWriter


echo "======================================================================"
echo "Task 4. Create and upload a data quality specification file to Cloud Storage"
echo "======================================================================"
cat > dq-customer-orders.yaml << EOF
rules:
- nonNullExpectation: {}
  column: user_id
  dimension: COMPLETENESS
  threshold: 1
- nonNullExpectation: {}
  column: order_id
  dimension: COMPLETENESS
  threshold: 1
postScanActions:
  bigqueryExport:
    resultsTable: projects/$DEVSHELL_PROJECT_ID/datasets/orders_dq_dataset/tables/results
EOF

gsutil cp dq-customer-orders.yaml gs://$DEVSHELL_PROJECT_ID-dq-config


echo "======================================================================"
echo " Task 5. Define and run an auto data quality job in Knowledge Catalog"
echo "======================================================================"
gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
    --project=$DEVSHELL_PROJECT_ID \
    --location=$REGION \
    --data-source-resource="//bigquery.googleapis.com/projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
    --data-quality-spec-file="gs://$DEVSHELL_PROJECT_ID-dq-config/dq-customer-orders.yaml"

gcloud dataplex datascans run customer-orders-data-quality-job \
    --location=$REGION


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"