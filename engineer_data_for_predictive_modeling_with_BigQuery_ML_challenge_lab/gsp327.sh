#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable \
    bigquery.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


read -p "ENTER the name of the COPY TABLE: " COPY_TABLE
read -p "ENTER the name of the TARGET COLUMN: " TARGET_COLUMN
read -p "ENTER the trip_distance LIMIT: " TRIP_DISTANCE_LIMIT
read -p "ENTER the fare_amount LIMIT: " FARE_AMOUNT_LIMIT
read -p "ENTER the passenger_count LIMIT: " PASSENGER_COUNT_LIMIT
read -p "ENTER the MODEL NAME: " MODEL_NAME


echo "======================================================================"
echo "                   Task 1. Clean your training data"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE
  taxirides.$TABLE_NAME AS
SELECT
  (tolls_amount + fare_amount) AS $TARGET_COLUMN,
  pickup_datetime,
  pickup_longitude AS pickuplon,
  pickup_latitude AS pickuplat,
  dropoff_longitude AS dropofflon,
  dropoff_latitude AS dropofflat,
  passenger_count AS passengers,
FROM
  taxirides.historical_taxi_rides_raw
WHERE
  RAND() < 0.001
  AND trip_distance > $TRIP_DISTANCE_LIMIT
  AND fare_amount >= $FARE_AMOUNT_LIMIT
  AND pickup_longitude > -78
  AND pickup_longitude < -70
  AND dropoff_longitude > -78
  AND dropoff_longitude < -70
  AND pickup_latitude > 37
  AND pickup_latitude < 45
  AND dropoff_latitude > 37
  AND dropoff_latitude < 45
  AND passenger_count > $PASSENGER_COUNT_LIMIT;
"


echo "======================================================================"
echo "                  Task 2. Create a BigQuery ML model"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE MODEL taxirides.$MODEL_NAME
TRANSFORM(
   * EXCEPT(pickup_datetime),
   ST_Distance(ST_GeogPoint(pickuplon, pickuplat), ST_GeogPoint(dropofflon, dropofflat)) AS euclidean,
   CAST(EXTRACT(DAYOFWEEK FROM pickup_datetime) AS STRING) AS dayofweek,
   CAST(EXTRACT(HOUR FROM pickup_datetime) AS STRING) AS hourofday
)
OPTIONS(input_label_cols=['$TARGET_COLUMN'], model_type='linear_reg') 
AS
SELECT * FROM taxirides.$TABLE_NAME;
"


echo "======================================================================"
echo "              Task 3. Perform a batch prediction on new data"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE taxirides.2015_fare_amount_predictions
AS
SELECT *
FROM ML.PREDICT(MODEL taxirides.$MODEL_NAME,
(SELECT * FROM taxirides.report_prediction_data));
"

echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"