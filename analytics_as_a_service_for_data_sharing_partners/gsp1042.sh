#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


read -p "ENTER the PARTNER_PROJECT: " PARTNER_PROJECT
read -p "ENTER the PROJECT A: " PROJECT_A
read -p "ENTER the PROJECT B: " PROJECT_B

read -p "ENTER the PARTNER Customer: " PARTNER_CUSTOMER
read -p "ENTER the Customer A: " CUSTOMER_A
read -p "ENTER the Customer B: " CUSTOMER_B


echo "======================================================================"
echo "                    Task 1. Create authorized views"
echo "======================================================================"
bq mk \
    --use_legacy_sql=false \
    --view='
        SELECT *
        FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
        WHERE state_code = "TX"
        LIMIT 4000
    ' \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_a"

bq mk \
    --use_legacy_sql=false \
    --view='
        SELECT *
        FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
        WHERE state_code = "CA"
        LIMIT 4000
    ' \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_b"


echo "======================================================================"
echo "         Task 2. Assign IAM permissions to both the views"
echo "======================================================================"
bq show --format=prettyjson \
    "$DEVSHELL_PROJECT_ID:demo_dataset" > dataset.json

jq --arg project "$DEVSHELL_PROJECT_ID" '
  .access += [
    {
      "view": {
        "projectId": $project,
        "datasetId": "demo_dataset",
        "tableId": "authorized_view_a"
      }
    },
    {
      "view": {
        "projectId": $project,
        "datasetId": "demo_dataset",
        "tableId": "authorized_view_b"
      }
    }
  ]
' dataset.json > dataset-updated.json

bq update \
    --source dataset-updated.json \
    "$DEVSHELL_PROJECT_ID:demo_dataset"

echo "======================================================================"
echo "     Task 3. Grant permissions to the users to access the views"
echo "======================================================================"
bq get-iam-policy \
    --format=json \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_a" \
    > view-a-policy.json

jq --arg member "user:$CUSTOMER_A" '
  .bindings = (
    .bindings // []
  ) + [{
    "role": "roles/bigquery.dataViewer",
    "members": [$member]
  }]
' view-a-policy.json > view-a-policy-updated.json

bq set-iam-policy \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_a" \
    view-a-policy-updated.json

bq get-iam-policy \
    --format=json \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_b" \
    > view-b-policy.json

jq --arg member "user:$CUSTOMER_B" '
  .bindings = (.bindings // []) + [
    {
      "role": "roles/bigquery.dataViewer",
      "members": [$member]
    }
  ]
' view-b-policy.json > view-b-policy-updated.json

bq set-iam-policy \
    "$DEVSHELL_PROJECT_ID:demo_dataset.authorized_view_b" \
    view-b-policy-updated.json


echo "======================================================================"
echo "                Task 4. Display insights for View A"
echo "======================================================================"
gcloud auth login $CUSTOMER_A \
    --no-launch-browser \
    --quiet

gcloud config set account $CUSTOMER_A

bq mk \
    --use_legacy_sql=false \
    --view="
        SELECT
            geos.zip_code,
            geos.city,
            cust.last_name,
            cust.first_name
        FROM \`${PROJECT_A}.customer_a_dataset.customer_info\` AS cust
        JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\` AS geos
        ON geos.zip_code = cust.postal_code;" \
    "${PROJECT_A}:customer_a_dataset.customer_a_table"

echo "======================================================================"
echo "                Task 4. Display insights for View B"
echo "======================================================================"
gcloud auth login $CUSTOMER_B \
    --no-launch-browser \
    --quiet

gcloud config set account $CUSTOMER_B

bq mk \
    --use_legacy_sql=false \
    --view="
        SELECT
            geos.zip_code,
            geos.city,
            cust.last_name,
            cust.first_name
        FROM \`${PROJECT_B}.customer_b_dataset.customer_info\` AS cust
        JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\` AS geos
        ON geos.zip_code = cust.postal_code;" \
    "${PROJECT_B}:customer_b_dataset.customer_b_table"


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"