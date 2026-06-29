#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=$PROJECT_ID


echo "======================================================================"
echo "   Task 1. Ensure that the Dataflow API is successfully re-enabled"
echo "======================================================================"
gcloud services disable dataflow.googleapis.com --project $PROJECT_ID --force
gcloud services enable dataflow.googleapis.com --project $PROJECT_ID

echo "======================================================================"
echo "Task 2. Create a BigQuery dataset, BigQuery table, and Cloud Storage bucket using Cloud Shell"
echo "======================================================================"
bq mk taxirides

bq mk --table taxirides.realtime --time_partitioning_field timestamp \
    --schema ride_id:string,point_idx:integer,latitude:float,longitude:float, timestamp:timestamp,meter_reading:float,meter_increment:float,ride_status:string,passenger_count:integer

echo "----------------------------------------------------------------------"
echo "           Create a Cloud Storage bucket using Cloud Shell"
echo "----------------------------------------------------------------------"
gsutil mb gs://$BUCKET

echo "======================================================================"
echo "                    Task 4. Run the pipeline"
echo "======================================================================"
gcloud dataflow jobs run iotflow \
    --gcs-location gs://dataflow-templates-$REGION/latest/PubSub_to_BigQuery \
    --region $REGION \
    --worker-machine-type e2-medium \
    --staging-location gs://$BUCKET/temp \
    --parameters inputTopic=projects/pubsub-public-data/topics/taxirides-realtime,outputTableSpec=$PROJECT_ID:taxirides.realtime

echo "======================================================================"
echo "                           JOB is DONE!"
echo "======================================================================"