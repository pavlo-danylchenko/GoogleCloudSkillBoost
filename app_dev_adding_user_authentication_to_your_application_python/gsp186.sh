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
gcloud config set project $DEVSHELL_PROJECT_ID

echo "======================================================================"
echo "                 Task 1. Prepare the case study application"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                    Clone source code in Cloud Shell"
echo "----------------------------------------------------------------------"
git clone https://github.com/GoogleCloudPlatform/training-data-analyst
ln -s ~/training-data-analyst/courses/developingapps/v1.3/python/firebase ~/firebase

echo "----------------------------------------------------------------------"
echo "              Configure and run the case study application"
echo "----------------------------------------------------------------------"
cd ~/firebase/start
sed -i "s/us-central/$REGION/g" prepare_environment.sh
. prepare_environment.sh

python run_server.py


# echo "======================================================================"
# echo "           Task 3. Configure Identity Platform Authentication"
# echo "======================================================================"
# gcloud services enable identitytoolkit.googleapis.com
# gcloud identity-platform config update \
#     --email-signin-enabled


# FULL_URL=$(web-preview-url)
# DOMAIN=$(echo $FULL_URL | sed -e 's|^https://||' -e 's|/.*$||')

# gcloud identity-platform config authorized-domains add --domains=$DOMAIN

# gcloud identity-platform users create \
#     --email="user1@example.com" \
#     --password="abc123!" \
#     --display-name="Quiz User"


# echo "======================================================================"
# echo "Task 4. Integrate a client-side web application with Identity Platform"
# echo "======================================================================"
# read -p "Update webapp/static/client/index.html and Press Enter to opcontinue..." </dev/tty
# web-preview-url