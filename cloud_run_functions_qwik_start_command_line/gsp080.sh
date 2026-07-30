#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


echo "======================================================================"
echo "                    Task 1. Create a function"
echo "======================================================================"
mkdir gcf_hello_world && cd $_

cat > index.js << EOF
const functions = require('@google-cloud/functions-framework');

// Register a CloudEvent callback with the Functions Framework that will
// be executed when the Pub/Sub trigger topic receives a message.
functions.cloudEvent('helloPubSub', cloudEvent => {
  // The Pub/Sub message is passed as the CloudEvent's data payload.
  const base64name = cloudEvent.data.message.data;

  const name = base64name
    ? Buffer.from(base64name, 'base64').toString()
    : 'World';

  console.log(`Hello, ${name}!`);
});
EOF

cat > package.json << EOF
{
  "name": "gcf_hello_world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

npm install

echo "======================================================================"
echo "                    Task 2. Deploy your function"
echo "======================================================================"

gcloud functions deploy nodejs-pubsub-function \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=helloPubSub \
  --trigger-topic cf-demo \
  --stage-bucket $PROJECT_ID-bucket \
  --service-account cloudfunctionsa@$PROJECT_ID.iam.gserviceaccount.com \
  --allow-unauthenticated

gcloud functions describe nodejs-pubsub-function \
  --region=$REGION

echo "======================================================================"
echo "                     Task 3. Test the function"
echo "======================================================================"
gcloud pubsub topics publish cf-demo --message="Cloud Function Gen2"


echo "======================================================================"
echo "                         Task 4. View logs"
echo "======================================================================"
gcloud functions logs read nodejs-pubsub-function \
  --region=$REGION