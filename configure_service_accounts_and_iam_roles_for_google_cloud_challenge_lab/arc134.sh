#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


cat > start.sh << 'EOF'
echo "======================================================================"
echo "        Task 2. Create a service account using the gcloud CLI"
echo "======================================================================"

gcloud auth login --quiet

export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud iam service-accounts create devops \
    --display-name devops \
    --quiet

gcloud config configurations activate default

SA=$(gcloud iam service-accounts list \
    --format="value(email)" \
    --filter "displayName=devops")


echo "======================================================================"
echo "Task 3. Grant IAM permissions to a service account using the gcloud CLI"
echo "======================================================================"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA \
    --role=roles/iam.serviceAccountUser

echo "======================================================================"
echo "Task 4. Create a compute instance with a service account attached using gcloud"
echo "======================================================================"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA \
    --role=roles/compute.instanceAdmin
 
sleep 5

gcloud compute instances create vm-2 \
    --zone=$ZONE \
    --service-account=$SA \
    --machine-type=e2-standard-2 \
    --scopes "https://www.googleapis.com/auth/compute"


echo "======================================================================"
echo "            Task 5. Create a custom role using a YAML file"
echo "======================================================================"
cat > role-definition.yaml << EOF_1
title: "Cloud SQL"
description: "Access to Cloud SQL"
includedPermissions:
- cloudsql.instances.connect
- cloudsql.instances.get
EOF_1

gcloud iam roles create cloudsql \
    --project $DEVSHELL_PROJECT_ID \
    --file role-definition.yaml


echo "======================================================================"
echo "Task 6. Use the client libraries to access BigQuery from a service account"
echo "======================================================================"

gcloud iam service-accounts create bigquery-qwiklab \
    --display-name "BigQuery User" \
    --quiet

BQ_SA=$(gcloud iam service-accounts list \
    --format="value(email)" \
    --filter "displayName='BigQuery User'")

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$BQ_SA \
    --role=roles/bigquery.user

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$BQ_SA \
    --role=roles/bigquery.dataViewer

gcloud compute instances create bigquery-instance \
    --zone=$ZONE \
    --service-account=$BQ_SA \
    --scopes=https://www.googleapis.com/auth/bigquery

sleep 10
EOF

gcloud compute ssh lab-vm \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh


cat > start_cloudsql.sh << 'EOF'
export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

BQ_SA=$(gcloud iam service-accounts list \
    --format="value(email)" \
    --filter "displayName='BigQuery User'")

sudo apt install python3 python3-pip python3.11-venv -y
python3 -m venv myvenv
source myvenv/bin/activate
sudo apt-get update
sudo apt-get install -y git python3-pip
pip3 install --upgrade pip
pip3 install google-cloud-bigquery pyarrow pandas db-dtypes

cat > query.sql << EOF_1
from google.auth import compute_engine
from google.cloud import bigquery
credentials = compute_engine.Credentials(
    service_account_email="$BQ_SA")
query = '''
SELECT name, SUM(number) as total_people
FROM "bigquery-public-data.usa_names.usa_1910_2013"
WHERE state = 'TX'
GROUP BY name, state
ORDER BY total_people DESC
LIMIT 20
'''
client = bigquery.Client(
    project=$DEVSHELL_PROJECT_ID',
    credentials=credentials)
print(client.query(query).to_dataframe())
EOF_1

python3 query.py

EOF

gcloud compute ssh bigquery-instance \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start_cloudsql.sh


echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"