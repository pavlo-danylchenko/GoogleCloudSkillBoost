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
echo "                    Task 1. Get the sample code"
echo "======================================================================"
gcloud storage cp -r gs://spls/gsp023/flex_and_vision/ .
cd flex_and_vision

echo "======================================================================"
echo "                    Task 2. Authenticate API requests"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

gcloud iam service-accounts create qwiklab \
  --display-name "My Qwiklab Service Account"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member serviceAccount:qwiklab@${PROJECT_ID}.iam.gserviceaccount.com \
--role roles/owner

gcloud iam service-accounts keys create ~/key.json \
--iam-account qwiklab@${PROJECT_ID}.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS="/home/${USER}/key.json"


echo "======================================================================"
echo "                 Task 3. Testing the application locally"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                       Install dependencies"
echo "----------------------------------------------------------------------"
pip install -r requirements.txt


echo "----------------------------------------------------------------------"
echo "                  Creating an App Engine app"
echo "----------------------------------------------------------------------"
gcloud app create --project=$PROJECT_ID --region=$REGION
# gcloud app deploy app.yaml --project $PROJECT_ID --quiet


echo "----------------------------------------------------------------------"
echo "                     Creating a storage bucket"
echo "----------------------------------------------------------------------"
export CLOUD_STORAGE_BUCKET=${PROJECT_ID}
gsutil mb gs://${PROJECT_ID}

echo "----------------------------------------------------------------------"
echo "                     Running the Application"
echo "----------------------------------------------------------------------"
python main.py


echo "======================================================================"
echo "                  The FIRST PART is DONE !!!"
echo "======================================================================"


# echo "======================================================================"
# echo "           Task 5. Deploying the App to App Engine Flexible"
# echo "======================================================================"
# sed -i "s/<your-cloud-storage-bucket>/$PROJECT_ID/g" main.py

# cat >> app.yaml << EOF
# manual_scaling:
#   instances: 1
# EOF

# gcloud config set app/cloud_build_timeout 1000
# gcloud app deploy app.yaml --project $PROJECT_ID --quiet

# echo "======================================================================"
# echo "                      JOB is DONE !!!"
# echo "======================================================================"