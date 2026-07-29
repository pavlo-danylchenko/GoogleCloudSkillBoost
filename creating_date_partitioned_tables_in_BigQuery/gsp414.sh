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

read -p "Input the Cluster Name: " CLUSTER_NAME
read -p "Input the Node Pool Name: " POOL_NAME
read -p "Input the Max Replicas number:" MAX_REPLICAS


echo "======================================================================"
echo "                   Task 1. Create a new dataset"
echo "======================================================================"
bq mk ecommerce


echo "======================================================================"
echo "               Task 2. Create tables with date partitions"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "       Query web page analytics for a sample of visitors in 2017"
echo "----------------------------------------------------------------------"
bq query --use_legacy_sql=false \
"
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE date = '20170708'
LIMIT 5
"

echo "----------------------------------------------------------------------"
echo "       Query web page analytics for a sample of visitors in 2018"
echo "----------------------------------------------------------------------"
bq query --use_legacy_sql=false \
"
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE date = '20180708'
LIMIT 5
"


echo "----------------------------------------------------------------------"
echo "            Create a new partitioned table based on date"
echo "----------------------------------------------------------------------"
bq quey --use_legacy_sql=false \
'
CREATE OR REPLACE TABLE ecommerce.partition_by_day
PARTITION BY date_formatted
OPTIONS(
  description="a table partitioned by date"
) AS
SELECT DISTINCT
PARSE_DATE("%Y%m%d", date) AS date_formatted,
fullvisitorId
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
'

echo "======================================================================"
echo "       Task 3. Review results from queries on a partitioned table"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
SELECT *
FROM \`data-to-insights.ecommerce.partition_by_day\`
WHERE date_formatted = "2016-08-01"
'

bq query --use_legacy_sql=false \
'
SELECT *
FROM \`data-to-insights.ecommerce.partition_by_day\`
WHERE date_formatted = "2018-07-08"
'


echo "======================================================================"
echo "         Task 4. Create an auto-expiring partitioned table"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
SELECT
  DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
  (SELECT ANY_VALUE(name) FROM \`bigquery-public-data.noaa_gsod.stations\` AS stations
  WHERE stations.usaf = stn) AS station_name, -- Stations may have multiple names
  prcp
FROM \`bigquery-public-data.noaa_gsod.gsod*\` AS weather
WHERE prcp < 99.9  -- Filter unknown values
  AND prcp > 0      -- Filter stations/days with no precipitation
  AND _TABLE_SUFFIX >= "2018"
ORDER BY date DESC -- Where has it rained/snowed recently
LIMIT 10
'


echo "======================================================================"
echo "            Task 5. Your turn: create a partitioned table"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
CREATE OR REPLACE TABLE ecommerce.days_with_rain
PARTITION BY date
OPTIONS (
  partition_expiration_days=730,
  description="weather stations with precipitation, partitioned by day"
) AS

SELECT
  DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
  (SELECT ANY_VALUE(name) FROM \`bigquery-public-data.noaa_gsod.stations\` AS stations
   WHERE stations.usaf = stn) AS station_name,  -- Stations may have multiple names
  prcp
FROM \`bigquery-public-data.noaa_gsod.gsod*\` AS weather
WHERE prcp < 99.9  -- Filter unknown values
  AND prcp > 0      -- Filter
  AND _TABLE_SUFFIX >= "2018"
'

echo "----------------------------------------------------------------------"
echo "             Confirm data partition expiration is working"
echo "----------------------------------------------------------------------"
bq query --use_legacy_sql=false \
'
SELECT
  AVG(prcp) AS average,
  station_name,
  date,
  CURRENT_DATE() AS today,
  DATE_DIFF(CURRENT_DATE(), date, DAY) AS partition_age,
  EXTRACT(MONTH FROM date) AS month
FROM ecommerce.days_with_rain
WHERE station_name = "WAKAYAMA" #Japan
GROUP BY station_name, date, today, month, partition_age
ORDER BY date DESC; # most recent days first
'


echo "======================================================================"
echo "  Task 6. Confirm the oldest partition_age is at or below 730 days"
echo "======================================================================"
bq query --use_legacy_sql=false \
'
SELECT
  AVG(prcp) AS average,
  station_name,
  date,
  CURRENT_DATE() AS today,
  DATE_DIFF(CURRENT_DATE(), date, DAY) AS partition_age,
  EXTRACT(MONTH FROM date) AS month
FROM ecommerce.days_with_rain
WHERE station_name = "WAKAYAMA" #Japan
GROUP BY station_name, date, today, month, partition_age
ORDER BY partition_age DESC
'

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"
