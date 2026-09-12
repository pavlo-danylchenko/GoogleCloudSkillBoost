#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable \
    run.googleapis.com \
    pubsub.googleapis.com \
    eventarc.googleapis.com


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket


echo "======================================================================"
echo "                    Task 1. Create a Pub/Sub topic"
echo "======================================================================"
export TOPIC_NAME=$DEVSHELL_PROJECT_ID-topic
export SUB_NAME=$DEVSHELL_PROJECT_ID-topic-sub

gcloud pubsub topics create $TOPIC_NAME
gcloud pubsub subscriptions create $SUB_NAME \
    --topic=$TOPIC_NAME


echo "======================================================================"
echo "                  Task 2. Create a Cloud Run sink"
echo "======================================================================"
gcloud run deploy pubsub-events \
    --image=gcr.io/cloudrun/hello \
    --quiet \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated



echo "======================================================================"
echo "   Task 3. Create and test a Pub/Sub event trigger using Eventarc"
echo "======================================================================"
gcloud eventarc triggers create pubsub-events-trigger \
    --location=$REGION \
    --destination-run-service=pubsub-events \
    --destination-run-region=$REGION \
    --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished" \
    --transport-topic=projects/$DEVSHELL_PROJECT_ID/topics/$TOPIC_NAME

gcloud  pubsub topics publish $TOPIC_NAME \
    --message="Hello from EVENTARC !!!"

echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"