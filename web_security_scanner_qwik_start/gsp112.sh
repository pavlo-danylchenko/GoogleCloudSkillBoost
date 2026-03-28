#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "           Task 1. Before you begin, you need an app to scan"
echo "======================================================================"
gsutil -m cp -r gs://spls/gsp067/python-docs-samples .
cd python-docs-samples/appengine/standard_python3/hello_world
sed -i "s/python37/python313/g" app.yaml

echo "itsdangerous==2.0.1" >> requirements.txt
echo "Jinja2==3.0.3" >> requirements.txt
echo "werkzeug==2.0.1" >> requirements.txt


echo "======================================================================"
echo "                        Task 2. Test app"
echo "======================================================================"
sudo apt update
sudo apt install python3-venv -y
python3 -m venv create myvenv
source myvenv/bin/activate

# flask --app main run

echo "======================================================================"
echo "                        Task 3. Deploy app"
echo "======================================================================"
gcloud app create --project=$DEVSHELL_PROJECT_ID --region=$REGION
gcloud app deploy app.yaml --project $DEVSHELL_PROJECT_ID --quiet

echo "======================================================================"
echo "                        Task 4. View app"
echo "======================================================================"
# gcloud app browse
export APP_URL="https://$(gcloud app describe --format='value(defaultHostname)')"

echo "======================================================================"
echo "                        Task 5. Run the scan"
echo "======================================================================"
# gcloud services enable websecurityscanner.googleapis.com

# gcloud alpha web-security-scanner scan-configs create \
#     --display-name="MyScan" \
#     --starting-urls="$APP_URL" \
#     --project=$DEVSHELL_PROJECT_ID

# SCAN_CONFIG_ID=$(gcloud alpha web-security-scanner scan-configs list \
#     --format="value(name)" \
#     --filter="displayName='MyScan'")

# echo "Found Scan Config: $SCAN_CONFIG_ID"

# gcloud alpha web-security-scanner scan-configs run $SCAN_CONFIG_ID
# gcloud alpha web-security-scanner scan-runs log \
#     --scan-config=$SCAN_CONFIG_ID \
#     --project=$DEVSHELL_PROJECT_ID

# curl -X POST \
#     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
#     -H "Content-Type: application/json" \
#     "https://websecurityscanner.googleapis.com/v1beta/${SCAN_CONFIG_ID}:run"

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"