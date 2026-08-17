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
gcloud config set run/region $REGION

gcloud services enable apigateway.googleapis.com --project $DEVSHELL_PROJECT_ID
gcloud services enable run.googleapis.com

sleep 20

PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID \
  --format="value(projectNumber)")

SERVICE_ACCOUNT="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

echo $SERVICE_ACCOUNT

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/artifactregistry.reader"

sleep 10


echo "======================================================================"
echo "                  Task 1. Create a Cloud Run function"
echo "======================================================================"
mkdir gcfunction & cd $_

cat > index.js << 'EOF'
import { http } from '@google-cloud/functions-framework';

http('helloWorld', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`Hello ${req.query.name || req.body.name || 'World'}!`);
});
EOF


cat > package.json << EOF
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  },
  "type": "module"
}
EOF

gcloud functions deploy gcfunction \
    --runtime nodejs22 \
    --trigger-http \
    --gen2 \
    --allow-unauthenticated \
    --region $REGION \
    --entry-point=helloWorld \
    --max-instances 5 \
    --source=./

sleep 30

echo "======================================================================"
echo "                    Task 2. Create an API Gateway"
echo "======================================================================"

cat > openapispec.yaml << EOF
swagger: '2.0'
info:
  title: gcfunction API
  description: Sample API on API Gateway with a Google Cloud Run functions backend
  version: 1.0.0
schemes:
- https
produces:
- application/json
x-google-backend:
  address: https://gcfunction-$PROJECT_NUMBER.$REGION.run.app
paths:
  /gcfunction:
    get:
      summary: gcfunction
      operationId: gcfunction
      responses:
       '200':
          description: A successful response
          schema:
            type: string
EOF

export API_ID="gcfunction-api"

gcloud api-gateway apis create $API_ID \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="gcfunction API"

gcloud api-gateway api-configs create gcfunction-api \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="gcfunction API config" \
    --api=$API_ID \
    --openapi-spec=openapispec.yaml \
    --backend-auth-service-account=$SERVICE_ACCOUNT

gcloud api-gateway gateways create gcfunction-api \
    --display-name="Hello Gateway" \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --api=$API_ID \
    --api-config=hello-world-config


echo "======================================================================"
echo " Task 3. Create a Pub/Sub Topic and Publish Messages via API Backend"
echo "======================================================================"
gcloud pubsub topics create demo-topic

gcloud pubsub subscriptions create demo-topic-sub \
    --topic=demo-topic
cd ~
mkdir pubsub & cd &_

cat > package.json << EOF
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^3.4.1"
  }
}
EOF

cat > index.js << EOF
/**
 * Responds to any HTTP request.
 *
 * @param {!express:Request} req HTTP request context.
 * @param {!express:Response} res HTTP response context.
 */
const {PubSub} = require('@google-cloud/pubsub');
const pubsub = new PubSub();
const topic = pubsub.topic('demo-topic');
const functions = require('@google-cloud/functions-framework');

exports.helloHttp = functions.http('helloHttp', (req, res) => {

  // Send a message to the topic
  topic.publishMessage({data: Buffer.from('Hello from Cloud Run functions!')});
  res.status(200).send("Message sent to Topic demo-topic!");
});
EOF

gcloud functions deploy gcfunction \
    --runtime nodejs22 \
    --trigger-http \
    --gen2 \
    --allow-unauthenticated \
    --region $REGION \
    --entry-point=helloWorld \
    --max-instances 5 \
    --source=./


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"