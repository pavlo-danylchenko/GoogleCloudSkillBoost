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

echo "======================================================================"
echo "                    Task 1. Create an API key"
echo "======================================================================"
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)
gcloud iam service-accounts create my-natlang-sa \
    --display-name "my natural language service account"

sleep 5

gcloud iam service-accounts keys create ~/key.json \
    --iam-account my-natlang-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com

sleep 5

export GOOGLE_APPLICATION_CREDEBTIALS="/home/USER/key.json"


echo "======================================================================"
echo "                Task 2. Make an entity analysis request"
echo "======================================================================"

# #ssh to linux-instance
# gcloud compute ssh [USER@]INSTANCE_NAME --zone=ZONE --project=PROJECT_ID --tunnel-through-iap
# [USER@]INSTANCE_NAME: The name of your VM instance and optional username.
# --zone=ZONE: The zone your instance is located in (e.g., us-central1-a).
# --project=PROJECT_ID: Your Google Cloud project ID.
# --tunnel-through-iap: (Optional) This flag routes the connection through the Identity-Aware Proxy, which is useful if your VM does not have an external IP address or you want to connect securely without opening firewall ports.

gcloud compute ssh linux-instance \
    --quiet \
    --project=$GOOGLE_CLOUD_PROJECT \
    --zone=$ZONE \
    --command="gcloud ml language analyze-entities --content=\"Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'.\" > result.json"


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"