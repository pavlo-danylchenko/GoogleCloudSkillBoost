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
echo "                   Task 1. Set up authorization"
echo "======================================================================"
gcloud services enable appengine.googleapis.com
sleep 10

gcloud app create --project=$PROJECT_ID --region=$REGION


echo "======================================================================"
echo "           Task 2. Get application information with apps.get"
echo "======================================================================"
gcloud app describe --project=$PROJECT_ID --format=json| jq -r .servingStatus


echo "======================================================================"
echo "                Task 3. Download the starter code"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/python-docs-samples
cd ~/python-docs-samples/appengine/standard_python3/hello_world


echo "======================================================================"
echo "                Task 4. Deploy your App Engine application"
echo "======================================================================"
gcloud app deploy app.yaml --project $PROJECT_ID --quiet


# echo "======================================================================"
# echo "Task 5. Configure ingress firewall rules with apps.firewall.ingressRules"
# echo "======================================================================"
# gcloud compute firewall-rules create deny-all\
#     --project=$PROJECT_ID \
#     --action=DENY \
#     --source-ranges=* \
#     --rules=tcp,icmp\
#     --priority=1 \
#     --direction=INGRESS

# gcloud compute firewall-rules delete deny-all

echo "======================================================================"
echo "               Task 6. Update your application files"
echo "======================================================================"
cd ~/python-docs-samples/appengine/standard_python3/hello_world
sed -i "s/Hello World/Goodbye World/g" main.py

echo "======================================================================"
echo "Task 7. Create a new version of your application with apps.services.versions.create"
echo "======================================================================"
gcloud app deploy -v v1 --quiet

echo "Job is Done !"