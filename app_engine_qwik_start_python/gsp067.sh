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


echo "======================================================================"
echo "              Task 1. Enable Google App Engine Admin API"
echo "======================================================================"
gcloud services enable appengine.googleapis.com


echo "======================================================================"
echo "           Task 2. Download the Hello World app"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/python-docs-samples
cd python-docs-samples/appengine/standard_python3/hello_world
sudo apt update
sudo apt install -y python3-venv
python3 -m venv myenv
source myenv/bin/activate

echo "======================================================================"
echo "                   Task 3. Test the application (Optional)"
echo "======================================================================"
# flask --app main run

echo "======================================================================"
echo "                    Task 4. Make a change"
echo "======================================================================"
sed -i "s/Hello World/Hello, Cruel World/g" main.py
# flask --app main run


echo "======================================================================"
echo "                    Task 5. Deploy your app"
echo "======================================================================"
gcloud app create --project=$PROJECT_ID --region=$REGION
gcloud app deploy app.yaml --project $PROJECT_ID --quiet


echo "======================================================================"
echo "                  Task 6. View your application"
echo "======================================================================"
gcloud app browse

echo "Job is Done !"