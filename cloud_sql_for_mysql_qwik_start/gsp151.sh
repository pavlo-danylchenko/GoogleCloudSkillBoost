#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                   Task 1. Create a Cloud SQL instance"
echo "======================================================================"
gcloud sql instance create myinstance \
    --database-version=MYSQL_8_0 \
    --region=$REGION \
    --zone=$ZONE \
    --tier=db-n1-standard-4 \
    --root-password=password123


echo "======================================================================"
echo "   Task 2. Connect to instance using the mysql client in Cloud Shell"
echo "======================================================================"
# gcloud sql connect myinstance --user=root


echo "======================================================================"
echo "            Task 3. Create a database and upload data"
echo "======================================================================"
gcloud sql databases create guestbook \
    --instance=myinstance

echo "JOB is DONE!"