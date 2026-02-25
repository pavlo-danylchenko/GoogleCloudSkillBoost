#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)


echo "======================================================================"
echo "              Task 1. Enable APIs and clone repository"
echo "======================================================================"
gcloud services enable cloudscheduler.googleapis.com

git clone https://github.com/GoogleCloudPlatform/gcf-automated-resource-cleanup.git && cd gcf-automated-resource-cleanup/
WORKDIR=$(pwd)

echo "======================================================================"
echo "                    Task 2. Create IP addresses"
echo "======================================================================"
cd $WORKDIR/unused-ip
export USED_IP=used-ip-address
export UNUSED_IP=unused-ip-address

gcloud compute addresses create $USED_IP --project=$PROJECT_ID --region=$REGION
gcloud compute addresses create $UNUSED_IP --project=$PROJECT_ID --region=$REGION

export USED_IP_ADDRESS=$(gcloud compute addresses describe $USED_IP --region=$REGION --format=json | jq -r '.address')


echo "======================================================================"
echo "                        Task 3. Create a VM"
echo "======================================================================"
gcloud compute instances create static-ip-instance \
    --zone $ZONE \
    --machine-type=e2-medium \
    --subnet=default \
    --address=$USED_IP_ADDRESS

echo "======================================================================"
echo "                Task 5. Deploy the Cloud Run function"
echo "======================================================================"
gcloud services disable cloudfunctions.googleapis.com
gcloud services enable cloudfunctions.googleapis.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_ID@appspot.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"

gcloud functions deploy unused_ip_function --gen2 --trigger-http --runtime=nodejs20 --region=$REGION --quiet

export FUNCTION_URL=$(gcloud functions describe unused_ip_function --region=$REGION --format=json | jq -r '.url')


echo "======================================================================"
echo "             Task 6. Schedule and test the Cloud Run function"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "          Create an App Engine app to use Cloud Scheduler"
echo "----------------------------------------------------------------------"
gcloud app create --region $REGION

echo "----------------------------------------------------------------------"
echo "Create a Cloud Scheduler task to run the Cloud Run function at 2 AM every night"
echo "----------------------------------------------------------------------"
gcloud scheduler jobs create http unused-ip-job \
    --schedule="* 2 * * *" \
    --uri=$FUNCTION_URL \
    --location=$REGION

echo "----------------------------------------------------------------------"
echo "               Test the job by manually triggering it"
echo "----------------------------------------------------------------------"
gcloud scheduler jobs run unused-ip-job --location=$REGION

echo "----------------------------------------------------------------------"
echo "            Confirm that the unused IP address was deleted"
echo "----------------------------------------------------------------------"
gcloud compute addresses list --filter="region:($REGION)"


echo "JOB is DONE!"

