#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "              Task 1. Enable APIs and download the source code"
echo "======================================================================"
gcloud services enable cloudscheduler.googleapis.com

gcloud storage cp -r gs://spls/gsp649/* . && cd gcf-automated-resource-cleanup/
export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
WORKDIR=$(pwd)

sudo apt-get update
sudo apt-get install apache2-utils -y

echo "======================================================================"
echo "         Task 2. Create the Cloud Storage buckets and add a file"
echo "======================================================================"
cd $WORKDIR/migrate-storage

gcloud storage buckets create  gs://${PROJECT_ID}-serving-bucket -l $REGION

# Make the bucket public
gsutil acl ch -u allUsers:R gs://${PROJECT_ID}-serving-bucket

gcloud storage cp $WORKDIR/migrate-storage/testfile.txt  gs://${PROJECT_ID}-serving-bucket

# Make the file public
gsutil acl ch -u allUsers:R gs://${PROJECT_ID}-serving-bucket/testfile.txt

curl http://storage.googleapis.com/${PROJECT_ID}-serving-bucket/testfile.txt

gcloud storage buckets create gs://${PROJECT_ID}-idle-bucket -l $REGION
export IDLE_BUCKET_NAME=$PROJECT_ID-idle-bucket


echo "======================================================================"
echo "              Task 3. Create a monitoring dashboard"
echo "======================================================================"


echo "======================================================================"
echo "              Task 4. Generate load on the serving bucket"
echo "======================================================================"
# ab -n 10000 http://storage.googleapis.com/$PROJECT_ID-serving-bucket/testfile.txt


echo "======================================================================"
echo "            Task 5. Review and deploy the Cloud Run function"
echo "======================================================================"
sed -i "s/<project-id>/$PROJECT_ID/" $WORKDIR/migrate-storage/main.py

gcloud services disable cloudfunctions.googleapis.com
gcloud services enable cloudfunctions.googleapis.com

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"

gcloud functions deploy migrate_storage \
    --gen2 \
    --trigger-http \
    --runtime=python310 \
    --region $REGION \
    --allow-unauthenticated

export FUNCTION_URL=$(gcloud functions describe migrate_storage --format=json --region $REGION | jq -r '.url')


echo "======================================================================"
echo "               Task 6. Test and validate alerting automation"
echo "======================================================================"
sed -i "s/\\\$IDLE_BUCKET_NAME/$IDLE_BUCKET_NAME/" $WORKDIR/migrate-storage/incident.json

envsubst < $WORKDIR/migrate-storage/incident.json | curl -X POST -H "Content-Type: application/json" $FUNCTION_URL -d @-

gsutil defstorageclass get gs://$PROJECT_ID-idle-bucket


echo "======================================================================"
echo "                      JOB is DONE !!!"
echo "======================================================================"