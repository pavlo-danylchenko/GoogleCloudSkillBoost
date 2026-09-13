#!/bin/bash
set -euo pipefail

# Build a Smart Cloud Application with Vibe Coding and MCP: Challenge Lab
#  NEED to complete...

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable \
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION

read -p "ENTER the MODEL NAME: " MODEL_NAME
read -p "ENTER the SECOND USER: " SECOND_USER

# read -p "ENTER the TOPIC NAME: " TOPIC_NAME
# read -p "ENTER the JOB NAME: " JOB_NAME

PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID \
  --format="value(projectNumber)")

SERVICE_ACCCOUNT=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
MCP_SERVER_URL="https://vibe-zoo-mcp-server-$PROJECT_NUMBER.$REGION.run.app/mcp/"

echo "======================================================================"
echo "     Task 1. Set up the environment and enable the necessary APIs"
echo "======================================================================"
gcloud storage cp gs://$DEVSHELL_PROJECT_ID-labconfig-bucket/labs_code.zip .
unzip labs_code.zip

cd ~/zoo_guide_agent
cat > .env << EOF 
MODEL="$MODEL_NAME"
SERVICE_ACCOUNT="$SERVICE_ACCCOUNT"
MCP_SERVER_URL="$MCP_SERVER_URL"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT=$DEVSHELL_PROJECT_ID
PROJECT_NUMBER=$PROJECT_NUMBER
GOOGLE_CLOUD_LOCATION=global
EOF


echo "======================================================================"
echo "      Task 2. Perform the necessary policy bindings (IAM setup)"
echo "======================================================================"
gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="user:$SECOND_USER" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="user:$SECOND_USER" \
  --role="roles/aiagentplatform.user"

sleep 5

echo "======================================================================"
echo "          Task 3. Fix and deploy the MCP server to Cloud Run"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                     Deploy and test locally"
echo "----------------------------------------------------------------------"
cd ~/mcp-on-cloudrun
sed -i "s/# mcp/mcp/g" server.py 

# uv run --python 3.13 local_mcp_call.py

echo "----------------------------------------------------------------------"
echo "                     Deploy and test locally"
echo "----------------------------------------------------------------------"


echo "======================================================================"
echo "                Task 4. Update the agent to use MCP"
echo "======================================================================"


echo "======================================================================"
echo "       Task 5. Dockerize and deploy the ADK agent to Cloud Run"
echo "======================================================================"


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"