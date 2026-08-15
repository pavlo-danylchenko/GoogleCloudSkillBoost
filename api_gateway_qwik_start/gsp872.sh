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

gcloud services enable apigateway.googleapis.com run.googleapis.com

sleep 30


echo "======================================================================"
echo "                  Task 1. Deploying an API backend"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/nodejs-docs-samples.git
cd nodejs-docs-samples/functions/helloworld/helloworldGet

gcloud functions deploy helloget \
    --runtime nodejs22 \
    --trigger-http \
    --allow-unauthenticated \
    --region $REGION

echo "======================================================================"
echo "                    Task 2. Test the API backend"
echo "======================================================================"
# gcloud functions describe helloget --region $REGION --project=$DEVSHELL_PROJECT_ID


# URL=$(gcloud run services describe helloget \
#   --region=$REGION \
#   --format=json| jq -r .metadata.annotations.run.googleapis.com/custom-audiences
# #   --format="value(URL)")

curl -sL -w "\n" https://$REGION-$DEVSHELL_PROJECT_ID.cloudfunctions.net/helloGET

echo "----------------------------------------------------------------------"
echo "                    Create the API definition"
echo "----------------------------------------------------------------------"
cd ~
cat > openapi2-functions.yaml << EOF
# openapi2-functions.yaml
swagger: '2.0'
info:
  title: API_ID description
  description: Sample API on API Gateway with a Google Cloud Functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
paths:
  /hello:
    get:
      summary: Greet a user
      operationId: hello
      x-google-backend:
        address: https://$REGION-$DEVSHELL_PROJECT_ID.cloudfunctions.net/helloGET
      responses:
       '200':
          description: A successful response
          schema:
            type: string
EOF

export API_ID="hello-world-$(cat /dev/urandom | tr -dc 'a-z' | fold -w ${1:-8} | head -n 1)"

sed -i "s/API_ID/${API_ID}/g" openapi2-functions.yaml


echo "======================================================================"
echo "                      Task 3. Creating a gateway"
echo "======================================================================"
gcloud api-gateway apis create $API_ID \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="Hello World API"

PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID \
  --format="value(projectNumber)")

SERVICE_ACCOUNT="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

echo $SERVICE_ACCOUNT

# gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
#     --member="serviceAccount:$SERVICE_ACCOUNT" \
#     --role="roles/serviceusage.serviceUsageAdmin"

# gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
#     --member="serviceAccount:$SERVICE_ACCOUNT" \
#     --role="roles/artifactregistry.reader"

# sleep 30

gcloud api-gateway api-configs create hello-world-config \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="Hello World Config" \
    --api=$API_ID \
    --openapi-spec=openapi2-functions.yaml \
    --backend-auth-service-account=$SERVICE_ACCOUNT

gcloud api-gateway gateways create hello-gateway \
    --display-name="Hello Gateway" \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --api=$API_ID \
    --api-config=hello-world-config


echo "----------------------------------------------------------------------"
echo "                    Testing your API Deployment (OPTIONAL)"
echo "----------------------------------------------------------------------"


echo "======================================================================"
echo "               Task 4. Securing access by using an API key"
echo "======================================================================"

gcloud services api-keys create --display-name="APIkey"
export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")
echo "API_KEY = $API_KEY"

MANAGED_SERVICE=$(gcloud api-gateway apis list --format json | jq -r .[0].managedService | cut -d'/' -f6)
echo $MANAGED_SERVICE

gcloud services enable $MANAGED_SERVICE


echo "----------------------------------------------------------------------"
echo "        Modify the OpenAPI Spec to leverage API Key Security"
echo "----------------------------------------------------------------------"
cat > openapi2-functions2.yaml << EOF
# openapi2-functions.yaml
swagger: '2.0'
info:
  title: $API_ID description
  description: Sample API on API Gateway with a Google Cloud Functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
paths:
  /hello:
    get:
      summary: Greet a user
      operationId: hello
      x-google-backend:
        address: https://$REGION-$DEVSHELL_PROJECT_ID.cloudfunctions.net/helloGET
      security:
        - api_key: []
      responses:
       '200':
          description: A successful response
          schema:
            type: string
securityDefinitions:
  api_key:
    type: "apiKey"
    name: "key"
    in: "query"
EOF

echo "======================================================================"
echo " Task 5. Create and deploy a new API config to your existing gateway"
echo "======================================================================"
gcloud api-gateway api-configs create hello-config \
    --project=$DEVSHELL_PROJECT_ID \
    --display-name="Hello Config" \
    --api=$API_ID \
    --openapi-spec=openapi2-functions2.yaml \
    --backend-auth-service-account=$SERVICE_ACCOUNT

gcloud api-gateway gateways update hello-gateway \
    --api-config=hello-config


echo "======================================================================"
echo "             Task 6. Testing calls using your API key"
echo "======================================================================"
export GATEWAY_URL=$(gcloud api-gateway gateways describe hello-gateway \
                        --location $REGION \
                        --format json | jq -r .defaultHostname)

curl -sL -w "\n" $GATEWAY_URL/hello?key=$API_KEY

echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"