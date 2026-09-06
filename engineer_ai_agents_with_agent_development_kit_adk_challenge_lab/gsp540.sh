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

read -p "ENTER the MODEL NAME: " MODEL_NAME

echo "======================================================================"
echo "            Task 1. Install ADK and set up your environment"
echo "======================================================================"
export PATH=$PATH:"/home/${USER}/.local/bin"
python3 -m pip install google-adk

gcloud auth application-default login

gcloud storage cp gs://$DEVSHELL_PROJECT_ID-bucket/adk_project.zip .
unzip adk_project.zip
cd adk_project
pip install -r requirements.txt


echo "======================================================================"
echo "           Task 2. Initialize and Configure the Travel Scout"
echo "======================================================================"
FOLDERS=("my_google_search_agent" "fogeo_validatorlder2" "llm_auditor")

for folder in "${FOLDERS[@]}"; do
cat > ~/adk_project/$folder/.env << EOF
GOOGLE_GENAI_USE_ENTERPRISE=true
GOOGLE_CLOUD_PROJECT=$DEVSHELL_PROJECT_ID
GOOGLE_CLOUD_LOCATION=global
MODEL=$MODEL_NAME
EOF
done

echo "======================================================================"
echo "               Task 3. Verify the agent via the CLI"
echo "======================================================================"
# echo "What is the currency exchange rate for Japan?" | adk run my_google_search_agent


echo "======================================================================"
echo "               Task 4. Enforce structured standards"
echo "======================================================================"


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"