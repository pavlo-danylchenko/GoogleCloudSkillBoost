#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

read -p "Enter the BigQuery Role: " BIGQUERY_ROLE
read -p "Enter the Cloud Storage Role: " CLOUD_STORAGE_ROLE
read -p "Enter the LANGUAGE: " LANGUAGE
read -p "Enter the LOCALE: " LOCALE

# export PROJECT_ID=$(gcloud config get project)
# export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "Task 1. Configure a service account to access the Machine Learning"
echo "            APIs, BigQuery, and Cloud Storage"
echo "======================================================================"
gcloud iam service-accounts create my-account --display-name my-account

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member=serviceAccount:my-account@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role=$BIGQUERY_ROLE
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member=serviceAccount:my-account@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role=$CLOUD_STORAGE_ROLE
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member=serviceAccount:my-account@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/serviceusage.serviceUsageConsumer

sleep 30

echo "======================================================================"
echo "Task 2. Create and download a credential file for your service account"
echo "======================================================================"

gcloud iam service-accounts keys create key.json \
    --iam-account=my-account@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=key.json


echo "======================================================================"
echo "  Task 3. Modify the Python script to extract text from image files"
echo " Task 4. Modify the Python script to translate the text using the Translation API"
echo "======================================================================"
curl -O https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/refs/heads/main/use_machine_learning_apis_on_google_cloud_challenge_lab/analyze-images-v2.py
sed -i "s/locale == 'en'/locale == '$LOCALE'/" analyze-images-v2.py
sed -i "s/target_language='en'/target_language='$LOCALE'/" analyze-images-v2.py

python3 analyze-images-v2.py $DEVSHELL_PROJECT_ID $DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "Task 5. Identify the most common language used in the signs in the dataset"
echo "======================================================================"
bq query --use_legacy_sql=false \
"SELECT
    locale,COUNT(locale) as lcount
FROM
    image_classification_dataset.image_text_detail
GROUP BY locale
ORDER BY lcount DESC"


echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"