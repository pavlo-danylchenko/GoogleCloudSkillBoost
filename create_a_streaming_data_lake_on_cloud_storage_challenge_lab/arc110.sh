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
    dataflow.googleapis.com \
    appengine.googleapis.com \
    cloudscheduler.googleapis.com \
    --project=$DEVSHELL_PROJECT_ID

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION

export TOPIC_NAME=topic1
export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket

echo "======================================================================"
echo "                    Task 1. Create a Pub/Sub topic"
echo "======================================================================"

gcloud pubsub topics create $TOPIC_NAME


echo "======================================================================"
echo "                Task 2. Create a Cloud Scheduler job"
echo "======================================================================"
gcloud app create --region=$REGION

gcloud scheduler jobs create pubsub cron-scheduler-job \
    --schedule="* * * * *" \
    --topic=$TOPIC_NAME \
    --message-body="Hello World!" \
    --location=$REGION

gcloud scheduler jobs run cron-scheduler-job \
    --location=$REGION 

sleep 10


echo "======================================================================"
echo "                Task 3. Create a Cloud Storage bucket"
echo "======================================================================"
gcloud storage buckets create gs://$BUCKET_NAME \
    --location=$REGION


echo "======================================================================"
echo "Task 4. Run a Dataflow pipeline to stream data from a Pub/Sub topic to Cloud Storage"
echo "======================================================================"
docker run -it -e DEVSHELL_PROJECT_ID=$DEVSHELL_PROJECT_ID python:3.7 /bin/bash
git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/pubsub/streaming-analytics
pip install -U -r requirements.txt  # Install Apache Beam dependencies

python PubSubToGCS.py \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION \
    --input_topic=projects/$DEVSHELL_PROJECT_ID/topics/$TOPIC_NAME \
    --output_path=gs://$BUCKET_NAME/samples/output \
    --runner=DataflowRunner \
    --window_size=2 \
    --num_shards=2 \
    --temp_location=gs://$BUCKET_NAME/temp \
    --worker_disk_type=compute.googleapis.com/projects/$DEVSHELL_PROJECT_ID/zones/$ZONE/diskTypes/pd-standard \
    --worker_machine_type=e2-standard-2

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"