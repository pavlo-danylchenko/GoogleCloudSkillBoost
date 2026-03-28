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
echo "                        Task 1. Create an API key"
echo "======================================================================"

gcloud alpha services api-keys create \
    --display-name="APIkey"

KEY_NAME=$(gcloud alpha services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

gcloud compute instances add-metadata linux-instance \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
#!/bin/bash

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)

echo "======================================================================"
echo "             Task 2. Create your Speech-to-Text API request"
echo "======================================================================"

cat > request.json << EOF_1
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
EOF_1


echo "======================================================================"
echo "                Task 3. Call the Speech-to-Text API"
echo "======================================================================"

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

echo "The analysis is complete. The results has been saved to result.json"
EOF

echo "Sending the script to the VM instance ..."
# gcloud compute scp ./start.sh linux-instance:~/ --zone=$ZONE

# To execute once:
gcloud compute ssh linux-instance \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"