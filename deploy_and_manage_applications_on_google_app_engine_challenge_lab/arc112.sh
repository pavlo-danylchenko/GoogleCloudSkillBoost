#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

read -p "Enter the NEW MESSAGE: " NEW_MESSAGE

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "             Task 1. Enable the Google App Engine Admin API"
echo "======================================================================"
gcloud services enable appengine.googleapis.com
sleep 10


echo "======================================================================"
echo "               Task 2. Download the Hello World app"
echo "======================================================================"
gcloud compute ssh lab-setup \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet \
    --command="git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"

echo "======================================================================"
echo "               Task 3. Deploy your application"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/appengine/standard_python3/hello_world

# gcloud app create --project=$DEVSHELL_PROJECT_ID --region=$REGION
# gcloud app deploy app.yaml --project=$DEVSHELL_PROJECT_ID --quiet

echo "======================================================================"
echo "             Task 4. Deploy updates to your application"
echo "======================================================================"
sed -i "s/Hello World/$NEW_MESSAGE/g" main.py

gcloud app create --project=$DEVSHELL_PROJECT_ID --region=$REGION
gcloud app deploy app.yaml --project=$DEVSHELL_PROJECT_ID --quiet


echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"