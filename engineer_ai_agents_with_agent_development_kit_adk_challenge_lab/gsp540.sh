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

cd ~

curl -O https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/refs/heads/main/engineer_ai_agents_with_agent_development_kit_adk_challenge_lab/geo_validator.py
curl -O https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/refs/heads/main/engineer_ai_agents_with_agent_development_kit_adk_challenge_lab/llm_auditor.py
curl -O https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/refs/heads/main/engineer_ai_agents_with_agent_development_kit_adk_challenge_lab/my_google_search_agent.py


echo "======================================================================"
echo "            Task 1. Install ADK and set up your environment"
echo "======================================================================"
export PATH=$PATH:"/home/${USER}/.local/bin"
python3 -m pip install google-adk

gcloud auth application-default login --quiet

gcloud storage cp gs://$DEVSHELL_PROJECT_ID-bucket/adk_project.zip .
unzip adk_project.zip
cd adk_project
pip install -r requirements.txt


echo "======================================================================"
echo "           Task 2. Initialize and Configure the Travel Scout"
echo "======================================================================"
FOLDERS=("my_google_search_agent" "geo_validator" "llm_auditor")

for folder in "${FOLDERS[@]}"; do
cp ~/$folder.py ~/adk_project/$folder/agent.py
cat > ~/adk_project/$folder/.env << EOF
GOOGLE_GENAI_USE_ENTERPRISE=true
GOOGLE_CLOUD_PROJECT=$DEVSHELL_PROJECT_ID
GOOGLE_CLOUD_LOCATION=global
MODEL=gemini-3.5-flash
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