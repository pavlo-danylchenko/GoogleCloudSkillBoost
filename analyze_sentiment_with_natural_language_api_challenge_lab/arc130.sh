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
    --display-name="APIkey" \
    --api-target=service=language.googleapis.com

KEY_NAME=$(gcloud alpha services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")


gcloud compute instances add-metadata lab-vm \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
#!/bin/bash

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)

echo "======================================================================"
echo "Task 3. Analyze syntax and parts of speech with the Natural Language API"
echo "======================================================================"
cat > analyze-request.json << EOF_01
{
  "document":{
    "type":"PLAIN_TEXT",
    "content": "Google, headquartered in Mountain View, unveiled the new Android phone at the Consumer Electronic Show.  Sundar Pichai said in his keynote that users love their new Android phones."
  },
  "encodingType": "UTF8"
}
EOF_01

echo "Analyzing text content..."
curl "https://language.googleapis.com/v1/documents:analyzeSyntax?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @analyze-request.json > analyze-response.txt

echo "The analysis is complete. The results has been saved to analyze-response.txt"


echo "======================================================================"
echo "      Task 4. Perform multilingual natural language processing"
echo "======================================================================"
cat > multi-nl-request.json << EOF_02
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"Le bureau japonais de Google est situé à Roppongi Hills, Tokyo."
  }
}
EOF_02

echo "Analyzing text content..."
curl "https://language.googleapis.com/v1/documents:analyzeSyntax?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @multi-nl-request.json > multi-response.txt

echo "The analysis is complete. The results has been saved to multi-response.txt"

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