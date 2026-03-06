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

gcloud services enable appengine.googleapis.com

echo "======================================================================"
echo "              Task 1. Enable Google App Engine Admin API"
echo "======================================================================"
gcloud services enable appengine.googleapis.com


echo "======================================================================"
echo "              Task 2. Download the Hello World app"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/php-docs-samples.git
cd php-docs-samples/appengine/standard/helloworld

sed -i 's/^runtime: php.*/runtime: php83/' app.yaml
grep runtime app.yaml


echo "======================================================================"
echo "                 Task 3. Deploy your app"
echo "======================================================================"
gcloud app create --project=$PROJECT_ID --region=$REGION
gcloud app deploy --project $PROJECT_ID --quiet


echo "======================================================================"
echo "                 Task 4. View your application"
echo "======================================================================"
gcloud app browse


echo "======================================================================"
echo "                     Task 5. Make a change"
echo "======================================================================"
sed -i "s/Hello World/Goodbye World/g" index.php
gcloud app deploy --project $PROJECT_ID --quiet
gcloud app 


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"