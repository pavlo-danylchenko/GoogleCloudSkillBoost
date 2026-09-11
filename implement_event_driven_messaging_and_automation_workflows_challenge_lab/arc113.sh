#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable cloudscheduler.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


echo "======================================================================"
echo "                    Task 1. Set up Cloud Pub/Sub"
echo "======================================================================"
gcloud pubsub topics create cloud-pubsub-topic

gcloud pubsub subscriptions create cloud-pubsub-subscription\
    --topic cloud-pubsub-topic


echo "======================================================================"
echo "                Task 2. Create a Cloud Scheduler job"
echo "======================================================================"
gcloud scheduler jobs create pubsub cron-scheduler-job \
    --schedule="* * * * *" \
    --topic=cloud-pubsub-topic \
    --message-body="Hello World!" \
    --location=$REGION

sleep 10


echo "======================================================================"
echo "             Task 3. Verify the results in Cloud Pub/Sub"
echo "======================================================================"
gcloud pubsub subscriptions pull cloud-pubsub-subscription --limit 5
 
echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"