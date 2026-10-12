#!/bin/bash
set -euo pipefail

# Speech to Text Transcription with the Speech-to-Text API

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


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"
gcloud services api-keys create \
    --display-name="APIkey" \
    --api-target=service=speech.googleapis.com

KEY_NAME=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")

echo "======================================================================"
echo "                  Task 2. Create your API request"
echo "======================================================================"
cat > request.json << EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/brooklyn_bridge.flac"
  }
}
EOF


echo "======================================================================"
echo "                Task 3. Call the Speech-to-Text API"
echo "======================================================================"

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

gcloud storage cp result.json gs://$DEVSHELL_PROJECT_ID-speech/result_en.json


echo "======================================================================"
echo "     Task 4. Speech-to-Text transcription in different languages"
echo "======================================================================"
cat > request.json << EOF
 {
  "config": {
      "encoding":"FLAC",
      "languageCode": "fr"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

cat result.json

gcloud storage cp result.json gs://$DEVSHELL_PROJECT_ID-speech/result_fr.json


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"