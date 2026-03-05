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
gcloud config set run/region $REGION


echo "======================================================================"
echo "                    Task 1. Create a bucket"
echo "======================================================================"
gsutil mb gs://$PROJECT_ID


echo "======================================================================"
echo "               Task 2. Upload an object into the bucket"
echo "======================================================================"
curl -LO https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/cloud_storage_qwik_start_cloud_console/kitten.png

gsutil cp kitten.png gs://$PROJECT_ID/


echo "======================================================================"
echo "                  Task 3. Share a bucket publicly"
echo "======================================================================"
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID


echo "======================================================================"
echo "                     Task 4. Create folders"
echo "======================================================================"
gsutil cp /dev/null gs://$PROJECT_ID/folder1/
gsutil cp /dev/null gs://$PROJECT_ID/folder1/folder2/folder3/


echo "======================================================================"
echo "                     Task 5. Delete a folder/bucket"
echo "======================================================================"
gsutil rm -r gs://$PROJECT_ID/folder1/folder2/folder3
# gcloud storage buckets delete gs://$PROJECT_ID --recursive

echo "Job is Done !"