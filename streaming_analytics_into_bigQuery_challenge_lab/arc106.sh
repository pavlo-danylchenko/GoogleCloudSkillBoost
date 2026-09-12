#!/bin/bash
set -euo pipefail

# Create a Streaming Data Lake on Cloud Storage: Challenge Lab

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable \
    pubsub.googleapis.com \
    storage.googleapis.com \
    --project=$DEVSHELL_PROJECT_ID

gcloud services disable dataflow.googleapis.com --project $DEVSHELL_PROJECT_ID --force
gcloud services enable dataflow.googleapis.com --project $DEVSHELL_PROJECT_ID

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION

read -p "ENTER the DATASET NAME: " DATASET_NAME
read -p "ENTER the TABLE NAME: " TABLE_NAME
read -p "ENTER the TOPIC NAME: " TOPIC_NAME
read -p "ENTER the JOB NAME: " JOB_NAME

echo "======================================================================"
echo "                 Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID \
    --location $REGION


echo "======================================================================"
echo "             Task 2. Create a BigQuery dataset and table"
echo "======================================================================"
bq --location=US mk --dataset $DEVSHELL_PROJECT_ID:$DATASET_NAME
bq mk --table $DEVSHELL_PROJECT_ID:$DATASET_NAME.$TABLE_NAME data:STRING


echo "======================================================================"
echo "                    Task 3. Set up a Pub/Sub topic"
echo "======================================================================"
gcloud pubsub topics create $TOPIC_NAME
gcloud pubsub subscriptions create $TOPIC_NAME-sub \
    --topic $TOPIC_NAME


echo "======================================================================"
echo "Task 4. Run a Dataflow pipeline to stream data from Pub/Sub to BigQuery"
echo "======================================================================"
gcloud dataflow jobs run $JOB_NAME \
    --gcs-location gs://dataflow-templates-$REGION/latest/PubSub_to_BigQuery \
    --region $REGION \
    --staging-location gs://$DEVSHELL_PROJECT_ID/temp \
    --parameters inputTopic=projects/$DEVSHELL_PROJECT_ID/topics/$TOPIC_NAME,outputTableSpec=$DEVSHELL_PROJECT_ID:$DATASET_NAME.$TABLE_NAME

sleep 10


echo "======================================================================"
echo "Task 5. Publish a test message to the topic and validate data in BigQuery"
echo "======================================================================"
gcloud pubsub topics publish $TOPIC_NAME \
    --message='{"data": "73.4 F"}'

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"