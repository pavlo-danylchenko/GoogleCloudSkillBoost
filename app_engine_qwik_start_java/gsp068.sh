#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "              Task 1. Download the sample HTTP Server app"
echo "======================================================================"
gcloud storage cp -r gs://spls/gsp068/appengine-java21/appengine-java21/* .
cd helloworld/http-server

echo "======================================================================"
echo "                 Task 2. Deploy and view your app"
echo "======================================================================"
gcloud app deploy --project $PROJECT_ID --quiet
gcloud app browse


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"