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
    --project=$PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
#!/bin/bash

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)

echo "======================================================================"
echo "                   Task 2. Make an entity analysis request"
echo "======================================================================"
cat > request.json << EOF_REQ
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"Joanne Rowling, who writes under the pen names J. K. Rowling and Robert Galbraith, is a British novelist and screenwriter who wrote the Harry Potter fantasy series."
  },
  "encodingType":"UTF8"
}
EOF_REQ


echo "======================================================================"
echo "                 Task 3. Call the Natural Language API"
echo "======================================================================"
curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json > result.json


echo "======================================================================"
echo "        Task 4. Sentiment analysis with the Natural Language API"
echo "======================================================================"
cat > request.json << EOF_REQ
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"Harry Potter is the best book. I think everyone should read it."
  },
  "encodingType": "UTF8"
}
EOF_REQ

curl "https://language.googleapis.com/v1/documents:analyzeSentiment?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json


echo "======================================================================"
echo "                Task 5. Analyzing entity sentiment"
echo "======================================================================"
cat > request.json << EOF_REQ
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"I liked the sushi but the service was terrible."
  },
  "encodingType": "UTF8"
}
EOF_REQ

curl "https://language.googleapis.com/v1/documents:analyzeEntitySentiment?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json
EOF

echo "Sending the script to the VM instance ..."
# gcloud compute scp ./start.sh linux-instance:~/ --zone=$ZONE

# To execute once:
gcloud compute ssh linux-instance \
    --zone=$ZONE \
    --quiet \
    --project=$PROJECT_ID \
    --command="bash -s" < ./start.sh


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"