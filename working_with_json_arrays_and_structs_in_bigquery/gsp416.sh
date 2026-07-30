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


echo "======================================================================"
echo "             Task 1. Create a new dataset to store your tables"
echo "======================================================================"
bq mk fruit_store

echo "----------------------------------------------------------------------"
echo "                Loading semi-structured JSON into BigQuery"
echo "----------------------------------------------------------------------"
bq mk --table $DEVSHELL_PROJECT_ID:fruit_store.fruit_details

bq load --source_format=NEWLINE_DELIMITED_JSON \
    --autodetect $DEVSHELL_PROJECT_ID:fruit_store.fruit_details \
    gs://data-insights-course/labs/optimizing-for-performance/shopping_cart.json


echo "======================================================================"
echo "             Task 3. Create your own arrays with ARRAY_AGG()"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(DISTINCT v2ProductName) AS products_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT v2ProductName)) AS distinct_products_viewed,
  ARRAY_AGG(DISTINCT pageTitle) AS pages_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT pageTitle)) AS distinct_pages_viewed
  FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date
'


echo "======================================================================"
echo "             Task 4. Query tables containing arrays"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
SELECT DISTINCT
  visitId,
  h.page.pageTitle
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`,
UNNEST(hits) AS h
WHERE visitId = 1501570398
LIMIT 10
'


echo "======================================================================"
echo "                    Task 5. Introduction to STRUCTs"
echo "======================================================================"


echo "======================================================================"
echo "                 Task 6. Practice with STRUCTs and arrays"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                    Practice ingesting JSON data"
echo "----------------------------------------------------------------------"
bq mk racing
# bq mk --table $DEVSHELL_PROJECT_ID:racing.fruit_details

cat > schema.json << EOF
[
    {
        "name": "race",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "participants",
        "type": "RECORD",
        "mode": "REPEATED",
        "fields": [
            {
                "name": "name",
                "type": "STRING",
                "mode": "NULLABLE"
            },
            {
                "name": "splits",
                "type": "FLOAT",
                "mode": "REPEATED"
            }
        ]
    }
]
EOF

bq load --source_format=NEWLINE_DELIMITED_JSON \
    --schema=schema.json \
    $DEVSHELL_PROJECT_ID:racing.race_results \
    gs://data-insights-course/labs/optimizing-for-performance/race_results.json



echo "======================================================================"
echo "                  Task 7. Lab question: STRUCT()"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
#standardSQL
SELECT COUNT(p.name) AS racer_count
FROM racing.race_results AS r, UNNEST(r.participants) AS p
'


echo "======================================================================"
echo "       Task 8. Lab question: Unpacking arrays with UNNEST( )"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
#standardSQL
SELECT
  p.name,
  SUM(split_times) as total_race_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_times
WHERE p.name LIKE "R%"
GROUP BY p.name
ORDER BY total_race_time ASC;
'


echo "======================================================================"
echo "                Task 9. Filter within array values"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
#standardSQL
SELECT
  p.name,
  split_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_time
WHERE split_time = 23.2;
'


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"