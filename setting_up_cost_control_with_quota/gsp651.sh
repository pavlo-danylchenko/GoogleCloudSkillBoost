#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "              Task 1. Query a public dataset in BigQuery"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
SELECT
    w1mpro_ep,
    mjd,
    load_id,
    frame_id
FROM
    `bigquery-public-data.wise_all_sky_data_release.mep_wise`
ORDER BY
    mjd ASC
LIMIT 500
"


echo "======================================================================"
echo "                 Task 3. Update BigQuery quota"
echo "======================================================================"
gcloud alpha services quota list \
    --service=bigquery.googleapis.com \
    --consumer=projects/${DEVSHELL_PROJECT_ID} \
    --filter="usage"


gcloud alpha services quota update \
    --consumer=projects/${DEVSHELL_PROJECT_ID} \
    --service bigquery.googleapis.com \
    --metric bigquery.googleapis.com/quota/query/usage \
    --value 262144 \
    --unit 1/d/{project}/{user} \
    --force

gcloud alpha services quota list \
    --service=bigquery.googleapis.com \
    --consumer=projects/${DEVSHELL_PROJECT_ID} \
    --filter="usage"


echo "======================================================================"
echo "                      Task 4. Rerun your query"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
SELECT
    w1mpro_ep,
    mjd,
    load_id,
    frame_id
FROM
    `bigquery-public-data.wise_all_sky_data_release.mep_wise`
ORDER BY
    mjd ASC
LIMIT 500
"


echo "======================================================================"
echo "                      JOB is DONE !!!"
echo "======================================================================"