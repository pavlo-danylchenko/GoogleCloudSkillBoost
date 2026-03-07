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

echo "======================================================================"
echo "       Task 2. Prepare a Cloud Storage bucket for access testing"
echo "======================================================================"
gsutil mb gs://$PROJECT_ID --project=$PROJECT_ID --location=US
curl -LO https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/refs/heads/main/cloud_iam_qwik_start/sample.txt
gsutil cp sample.txt gs://$PROJECT_ID/


echo "======================================================================"
echo "                Task 3. Remove project access"
echo "======================================================================"
read -p "Enter USER's #2 e-mail: " USER_2_EMAIL

gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_2_EMAIL" \
    --role="roles/viewer"


read -p "Check the progress to verify the objective and Press [Enter] key to continue..."

echo "======================================================================"
echo "                Task 4. Add Cloud Storage permissions"
echo "======================================================================"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_2_EMAIL" \
    --role="roles/storage.objectViewer"

# gsutil ls gs://$PROJECT_ID

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"