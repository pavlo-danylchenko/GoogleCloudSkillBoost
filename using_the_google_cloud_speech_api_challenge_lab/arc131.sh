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


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"
gcloud services api-keys create \
    --display-name="API key 1" \
    --api-target=service=speech.googleapis.com

sleep 5

KEY_NAME=$(gcloud services api-keys list --filter="display_name='API key 1'" --format="value(name)")
API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")


gcloud compute instances add-metadata lab-vm \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)
echo "API Key retrieved from metadata: $API_KEY"

echo "======================================================================"
echo "             Task 2. Transcribe speech to English text"
echo "======================================================================"
cat > speech_request.json << EOF_1
{
  "config": {
      "encoding":"LINEAR16",
      "audioChannelCount": 2,
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://spls/arc131/question_en.wav"
  }
}
EOF_1

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @speech_request.json \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    > response.json


echo "======================================================================"
echo "               Task 3. Transcribe speech to Spanish text"
echo "======================================================================"
cat > request_speech_sp.json << EOF_3
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "es-ES"
  },
  "audio": {
      "uri":"gs://spls/arc131/multi_es.flac"
  }
}
EOF_3

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @request_speech_sp.json \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    > speech_response_sp.json
EOF

# To execute once:
gcloud compute ssh lab-vm \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"