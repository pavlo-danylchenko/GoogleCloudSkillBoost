#!/bin/bash
set -euo pipefail

# Stream Processing with Cloud Pub/Sub and Dataflow: Qwik Start

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "         Ensure that the Dataflow API is successfully enabled"
echo "----------------------------------------------------------------------"
gcloud services disable dataflow.googleapis.com
gcloud services enable dataflow.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


echo "======================================================================"
echo "                  Task 1. Create project resources"
echo "======================================================================"
TOPIC_ID=my-id
BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket

gcloud storage buckets create gs://$BUCKET_NAME

gcloud pubsub topics create $TOPIC_ID

gcloud app create --region=$REGION

gcloud scheduler jobs create pubsub publisher-job --schedule="* * * * *" \
    --topic=$TOPIC_ID --message-body="Hello!"

gcloud scheduler jobs run publisher-job

# docker run -it -e DEVSHELL_PROJECT_ID=$DEVSHELL_PROJECT_ID python:3.7 /bin/bash
git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/pubsub/streaming-analytics
pip install -U -r requirements.txt  # Install Apache Beam dependencies

echo "======================================================================"
echo "Task 2. Review code to stream messages from Pub/Sub to Cloud Storage (OPTIONAL)"
echo "======================================================================"

echo "======================================================================"
echo "                    Task 3. Start the pipeline"
echo "======================================================================"
python PubSubToGCS.py \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION \
    --input_topic=projects/$DEVSHELL_PROJECT_ID/topics/$TOPIC_ID \
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