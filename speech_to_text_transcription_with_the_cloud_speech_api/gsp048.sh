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
# 1. Enable the required service for API keys management
gcloud services enable apikeys.googleapis.com

# 2. Create the API key
gcloud services api-keys create --display-name="Speech-to-Text Key"

# 3. Wait a few seconds for the key to be fully provisioned
sleep 3

# 4. Get the Key ID and the Key String
export KEY_NAME=$(gcloud services api-keys list --filter="displayName='Speech-to-Text Key'" --format="value(name)")
export API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")

# 5. Restrict the key to only the Speech-to-Text API
gcloud services api-keys update $KEY_NAME --api-target=service=speech.googleapis.com

echo "SUCCESS: API Key created and restricted."
echo "You can now use \$API_KEY in your curl requests."


# SSH to the VM instance and set the API key as a metadata value
gcloud compute instances add-metadata linux-instance \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY

cat > start.sh << 'EOF'
#!/bin/bash

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)
echo "API Key retrieved from metadata: $API_KEY"

echo "======================================================================"
echo "                  Task 2. Create your API request"
echo "======================================================================"
cat > request.json << EOF_1
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/brooklyn_bridge.flac"
  }
}
EOF_1


echo "======================================================================"
echo "                Task 3. Call the Speech-to-Text API"
echo "======================================================================"
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

echo "The analysis is complete. The results has been saved to result.json"

# read -p "Check the progress to verify the objective and Press [Enter] key to continue with the next task..."
echo "Check the progress to verify the objective and Press [Enter] key to continue with the next task (you have 120 sec to do that)..."
sleep 120

echo "======================================================================"
echo "     Task 4. Speech-to-Text transcription in different languages"
echo "======================================================================"
cat > request.json << EOF_2
 {
  "config": {
      "encoding":"FLAC",
      "languageCode": "fr"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
EOF_2

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

cat result.json

EOF

echo "Sending the script to the VM instance ..."
# gcloud compute scp ./start.sh linux-instance:~/ --zone=$ZONE

# WARM-UP
gcloud compute ssh linux-instance --zone=$ZONE --quiet --command="true"

# To execute once:
gcloud compute ssh linux-instance \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --tunnel-through-iap \
    --command="bash -s" < ./start.sh


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"