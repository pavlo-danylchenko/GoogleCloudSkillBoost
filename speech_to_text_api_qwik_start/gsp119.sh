#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

read -p "INPUT PROJECT ID: " PROJECT_ID

gcloud config set project $PROJECT_ID
export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"

gcloud services api-keys create \
    --display-name="APIkey" \
    --api-target=service=speech.googleapis.com

KEY_NAME=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")

cat > request.json << EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

gcloud storage cp result.json gs://$DEVSHELL_PROJECT_ID-speech/


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"