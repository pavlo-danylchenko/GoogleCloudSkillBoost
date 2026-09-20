#!/bin/bash
set -euo pipefail

# BigQuery: Qwik Start - Command Line

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"


echo "======================================================================"
echo "                       Task 1. Open BigQuery"
echo "======================================================================"


echo "======================================================================"
echo "                 Task 2. Query a public dataset"
echo "======================================================================"
bq query --use_legace_sql=false \
'
#standardSQL
SELECT
 weight_pounds, state, year, gestation_weeks
FROM
 `bigquery-public-data.samples.natality`
ORDER BY weight_pounds DESC LIMIT 10;'

echo "======================================================================"
echo "                    Task 3. Create a new dataset"
echo "======================================================================"
bq mk babynames


echo "======================================================================"
echo "                 Task 4. Load data into a new table"
echo "======================================================================"
bq load babynames.names_2014 gs://spls/gsp072/baby-names/yob2014.txt name:string,gender:string,count:integer

echo "======================================================================"
echo "                      Task 5. Preview the table"
echo "======================================================================"


echo "======================================================================"
echo "                     Task 6. Query a custom dataset"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
#standardSQL
SELECT
 name, count
FROM
 `babynames.names_2014`
WHERE
 gender = "M"
ORDER BY count DESC LIMIT 5;
'


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"