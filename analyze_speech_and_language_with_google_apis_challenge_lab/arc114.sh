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
    --api-target=service=language.googleapis.com \
    --api-target=service=speech.googleapis.com

sleep 5

KEY_NAME=$(gcloud services api-keys list --filter="display_name='API key 1'" --format="value(name)")
API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")


gcloud compute instances add-metadata lab-vm \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
source venv/bin/activate

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)
echo "API Key retrieved from metadata: $API_KEY"

echo "======================================================================"
echo "Task 2. Make an entity analysis request and call the Natural Language API"
echo "======================================================================"
cat > nl_request.json << EOF_1
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  },
  "encodingType":"UTF8"
}
EOF_1

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @nl_request.json "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
    > nl_response.json


echo "======================================================================"
echo "   Task 3. Create a speech analysis request and call the Speech API"
echo "======================================================================"
cat > speech_request.json << EOF_3
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
EOF_3

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @speech_request.json "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    > speech_response.json


echo "======================================================================"
echo "       Task 4. Analyze sentiment with the Natural Language API"
echo "======================================================================"

gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
tar zxvf sentiment-samples.tgz
# python3 sentiment_analysis.py reviews/bladerunner-pos.txt
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