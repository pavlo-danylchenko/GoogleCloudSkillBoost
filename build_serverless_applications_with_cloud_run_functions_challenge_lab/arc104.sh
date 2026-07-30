#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com

read -p "INPUT Cloud Storage Function Name: " CSF_NAME
read -p "INPUT HTTP Cloud Function Name: " HTTP_F_NAME

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


echo "======================================================================"
echo "                 Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
gsutil mb -l $REGION $DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "       Task 2. Create, deploy, and test a Cloud Storage function"
echo "======================================================================"
mkdir ~/cloud-storage && cd $_
cat > index.js << EOF
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('eventStorage', (cloudevent) => {
  console.log('A new event in your Cloud Storage bucket has been logged!');
  console.log(cloudevent);
});
EOF

cat > package.json << EOF
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

npm install

# PROJECT_NUMBER=$(gcloud projects list --filter="project_id:$DEVSHELL_PROJECT_ID" --format='value(project_number)')
# SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)

# gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
#   --member serviceAccount:$SERVICE_ACCOUNT \
#   --role roles/pubsub.publisher

gcloud functions deploy $CSF_NAME \
  --gen2 \
  --runtime nodejs24 \
  --entry-point $CSF_NAME \
  --source . \
  --region $REGION \
  --trigger-bucket $DEVSHELL_PROJECT_ID \
  --trigger-location $REGION \
  --max-instances 2 \
  --quiet


echo "======================================================================"
echo "   Task 3. Create and deploy a HTTP function with minimum instances"
echo "======================================================================"
mkdir ~/gcf_hello_world && cd $_

cat > index.js << EOF
const functions = require('@google-cloud/functions-framework');

functions.http('helloWorld', (req, res) => {
  res.status(200).send('HTTP function (2nd gen) has been called!');
});
EOF

cat > package.json << EOF
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

npm install

gcloud functions deploy $HTTP_F_NAME \
  --gen2 \
  --runtime nodejs22 \
  --entry-point $HTTP_F_NAME \
  --source . \
  --region $REGION \
  --trigger-http \
  --timeout 600s \
  --max-instances 2 \
  --min-instances 1 \
  --quiet


echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"