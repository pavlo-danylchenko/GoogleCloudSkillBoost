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

export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket


echo "======================================================================"
echo "                    Task 1. Verify your resources"
echo "======================================================================"
gcloud services api-keys create \
    --display-name="APIKey" \
    --api-target=service=vision.googleapis.com

KEY_NAME=$(gcloud alpha services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

gsutil acl ch -u allUsers:R gs://$DEVSHELL_PROJECT_ID-bucket/manif-des-sans-papiers.jpg


echo "======================================================================"
echo "                  Task 2. Create Request.json file"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$DEVSHELL_PROJECT_ID-bucket/manif-des-sans-papiers.jpg"
          }
        },
        "features": [
          {
            "type": "TEXT_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @request.json "https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" \
    > text-response.json

echo "----------------------------------------------------------------------"
echo "                   Upload output to Cloud Storage"
echo "----------------------------------------------------------------------"
gcloud storage cp text-response.json gs://$BUCKET_NAME/

sed -i "s/TEXT_DETECTION/LANDMARK_DETECTION/g" request.json

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @request.json "https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" \
    > landmark-response.json


echo "----------------------------------------------------------------------"
echo "                   Upload output to Cloud Storage"
echo "----------------------------------------------------------------------"
gcloud storage cp landmark-response.json gs://$BUCKET_NAME/


echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"