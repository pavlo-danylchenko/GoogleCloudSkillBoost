#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)
# sudo apt-get update
# sudo apt-get install jq -y

echo "======================================================================"
echo "                   Task 1. Set up authorization"
echo "======================================================================"
gcloud iam service-accounts create quickstart
gcloud iam service-accounts keys create key.json --iam-account quickstart@$PROJECT_ID.iam.gserviceaccount.com
sleep 5
gcloud auth activate-service-account --key-file=key.json

export AUTH_TOKEN=$(gcloud auth print-access-token)


echo "======================================================================"
echo "                 Task 2. Make an annotate video request"
echo "======================================================================"
cat > request.json << EOF
{
   "inputUri":"gs://spls/gsp154/video/train.mp4",
   "features": [
       "LABEL_DETECTION"
   ]
}
EOF

export OPERATION_NAME=$(curl -s -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$(gcloud auth print-access-token)'' \
    'https://videointelligence.googleapis.com/v1/videos:annotate' \
    -d @request.json | jq -r .name)

curl -s -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$(gcloud auth print-access-token)'' \
    "https://videointelligence.googleapis.com/v1/$OPERATION_NAME"

sleep 60

curl -s -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$(gcloud auth print-access-token)'' \
    "https://videointelligence.googleapis.com/v1/$OPERATION_NAME"

echo "JOB is DONE !"