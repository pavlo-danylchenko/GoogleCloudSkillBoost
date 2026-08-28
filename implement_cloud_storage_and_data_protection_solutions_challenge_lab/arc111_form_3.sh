#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION

read -p "ENTER the BUCKET NAME #1: " BUCKET_NAME_1
read -p "ENTER the BUCKET NAME #2: " BUCKET_NAME_2
read -p "ENTER the BUCKET NAME #3: " BUCKET_NAME_3


echo "======================================================================"
echo "          Task 1. Create a bucket with Nearline Storage class"
echo "======================================================================"
# RAPID | STANDARD | NEARLINE | COLDLINE | ARCHIVE
gcloud storage buckets create gs://$BUCKET_NAME_1 \
    --default-storage-class=NEARLINE \
    --location=$REGION

echo "======================================================================"
echo "        Task 2. Update the file content of Cloud storage object"
echo "======================================================================"
export TEXT="This is an example of editing the file content for cloud storage object"
gcloud storage cp gs://$BUCKET_NAME_2/sample.txt .
echo "$TEXT" >> sample.txt
gcloud storage cp sample.txt gs://$BUCKET_NAME_2/sample.txt


echo "======================================================================"
echo "      Task 3. Change the storage class of bucket to Archive type"
echo "======================================================================"
gcloud storage buckets update gs://$BUCKET_NAME_2 \
    --default-storage-class=ARCHIVE

 
echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"