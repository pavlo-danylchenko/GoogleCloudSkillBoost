#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $REGION
echo $ZONE

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud services enable iap.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com

echo "----------------------------------------------------------------------"
echo "                        Download the code"
echo "----------------------------------------------------------------------"
gsutil cp gs://spls/gsp499/user-authentication-with-iap.zip .
# gsutil cp gs://$DEVSHELL_PROJECT_ID-bucket/user-authentication-with-iap.zip .

unzip user-authentication-with-iap.zip
cd user-authentication-with-iap


echo "======================================================================"
echo "          Task 1. Deploy the application and protect it with IAP"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                         Deploy to Cloud Run"
echo "----------------------------------------------------------------------"
cd 1-HelloWorld
gcloud run deploy user-auth-lab \
    --source . \
    --allow-unauthenticated \
    --region=$REGION \
    --quiet

echo "----------------------------------------------------------------------"
echo "                      Restrict access with IAP"
echo "----------------------------------------------------------------------"
gcloud run services update user-auth-lab \
    --region=$REGION \
    --iap

echo "----------------------------------------------------------------------"
echo "                     Test that IAP is turned on"
echo "----------------------------------------------------------------------"
export STUDENT_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

echo "STUDENT_EMAIL = $STUDENT_EMAIL"

gcloud iap web add-iam-policy-binding \
    --member="user:${STUDENT_EMAIL}" \
    --role="roles/iap.httpsResourceAccessor" \
    --region="$REGION" \
    --resource-type="cloud-run" \
    --service="user-auth-lab"

# gcloud run services add-iam-policy-binding user-auth-lab \
#     --region="$REGION" \
#     --member="user:${STUDENT_EMAIL}" \
#     --role="roles/run.invoker"

# read -p "Check the TASK #2 Progress and hit ANY KEY..."

echo "======================================================================"
echo "               Task 2. Access user identity information"
echo "======================================================================"
cd ~/user-authentication-with-iap/2-HelloUser

echo "----------------------------------------------------------------------"
echo "                      Deploy to Cloud Run"
echo "----------------------------------------------------------------------"
gcloud run deploy user-auth-lab \
    --source . \
    --region=$REGION \
    --quiet

echo "----------------------------------------------------------------------"
echo "                      Test the updated app"
echo "----------------------------------------------------------------------"
export SERVICE_URL=$(gcloud run services describe user-auth-lab --region=$REGION --format='value(status.url)')
echo "SERVICE_URL = $SERVICE_URL"

echo "----------------------------------------------------------------------"
echo "                         Turn off IAP"
echo "----------------------------------------------------------------------"
gcloud run services update user-auth-lab \
    --region=$REGION \
    --no-iap \
    --ingress=all \
    --no-invoker-iam-check

curl -X GET $SERVICE_URL -H "X-Goog-Authenticated-User-Email: totally fake email"

# gcloud run services add-iam-policy-binding user-auth-lab \
#     --region="$REGION" \
#     --member="allUsers" \
#     --role="roles/run.invoker"

# gcloud iap web add-iam-policy-binding \
#     --member="allUsers" \
#     --role="roles/iap.httpsResourceAccessor" \
#     --region="$REGION" \
#     --resource-type="cloud-run" \
#     --service="user-auth-lab"

sleep 10

read -p "Check the TASK #2 Progress and hit ANY KEY..."

echo "======================================================================"
echo "               Task 3. Use cryptographic verification"
echo "======================================================================"
cd ~/user-authentication-with-iap/3-HelloVerifiedUser

echo "----------------------------------------------------------------------"
echo "                      Deploy to Cloud Run"
echo "----------------------------------------------------------------------"
export PROJECT_NUMBER=$(gcloud projects describe "$DEVSHELL_PROJECT_ID" \
    --format="value(projectNumber)")

export IAP_AUDIENCE="/projects/$PROJECT_NUMBER/locations/$REGION/services/user-auth-lab"

echo "IAP_AUDIENCE=$IAP_AUDIENCE"

gcloud run deploy user-auth-lab \
    --source . \
    --set-env-vars="IAP_AUDIENCE=$IAP_AUDIENCE" \
    --region="$REGION" \
    --quiet

echo "----------------------------------------------------------------------"
echo "                  Test the cryptographic verification"
echo "----------------------------------------------------------------------"
gcloud run services update user-auth-lab \
    --region=$REGION \
    --iap

gcloud run services add-iam-policy-binding user-auth-lab \
    --member="serviceAccount:service-$(gcloud projects describe $DEVSHELL_PROJECT_ID --format='value(projectNumber)')@gcp-sa-iap.iam.gserviceaccount.com" \
    --role="roles/run.invoker" \
    --region=$REGION

echo "SERVICE_URL = $SERVICE_URL"

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"