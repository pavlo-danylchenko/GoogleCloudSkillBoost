#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
echo $DEVSHELL_PROJECT_ID
echo $GOOGLE_CLOUD_PROJECT
echo $PROJECT_ID

export PROJECT_ID=$(gcloud config get project)
echo $PROJECT_ID

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE


echo "======================================================================"
echo "             Task 1. Enable Cloud Scheduler API"
echo "======================================================================"
gcloud services enable cloudscheduler.googleapis.com
sleep 20


echo "======================================================================"
echo "             Task 2. Set up Cloud Pub/Sub"
echo "======================================================================"
gcloud pubsub topics create cron-topic
gcloud pubsub subscriptions create cron-sub --topic cron-topic


echo "======================================================================"
echo "             Task 3. Create a job"
echo "======================================================================"
gcloud schduler jobs create pubsub pubsub-job \
    --schedule="* * * * *" \
    --topic=cron-topic \
    --message-body="hello cron!" \
    --location=$REGION

# Even if you don't plan to use App Engine for your code,
# the Scheduler needs this "placeholder" to function.
# gcloud app create --region=$REGION

echo "======================================================================"
echo "           Task 4. Verify the results in Cloud Pub/Sub"
echo "======================================================================"
gcloud pubsub subscriptions pull cron-sub --limit 5

echo "JOB is DONE!"