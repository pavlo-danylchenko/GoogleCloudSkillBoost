#!/bin/bash
set -euo pipefail

# Dataflow: Qwik Start - Python

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable \
    pubsub.googleapis.com \
    storage.googleapis.com \
    appengine.googleapis.com \
    cloudscheduler.googleapis.com \
    --project=$DEVSHELL_PROJECT_ID


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

export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket

echo "======================================================================"
echo "                Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
gcloud storage buckets create gs://$BUCKET_NAME \
    --location=us


echo "======================================================================"
echo "              Task 2. Install the Apache Beam SDK for Python"
echo "======================================================================"
# docker run -it -e DEVSHELL_PROJECT_ID=$DEVSHELL_PROJECT_ID python:3.12 /bin/bash

pip install 'apache-beam[gcp]'==2.67.0

echo "======================================================================"
echo "           Task 3. Run an example Dataflow pipeline remotely"
echo "======================================================================"

python -m apache_beam.examples.wordcount --project $DEVSHELL_PROJECT_ID \
  --runner DataflowRunner \
  --staging_location=gs://$BUCKET_NAME/staging \
  --temp_location=gs://$BUCKET_NAME/temp \
  --output=gs://$BUCKET_NAME/results/output \
  --region=$REGION \
  --worker_machine_type=e2-standard-2


echo "======================================================================"
echo "           Task 4. Check that your Dataflow job succeeded"
echo "======================================================================"

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"