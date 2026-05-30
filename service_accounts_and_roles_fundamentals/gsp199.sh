#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "          Task 1. Create and manage service accounts"
echo "======================================================================"
gcloud iam service-accounts create my-sa-123 --display-name "my service account"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member=serviceAccount:my-sa-123@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/editor

echo "======================================================================"
echo "Task 2. Use the client libraries to access BigQuery using a service account"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Create a service account"
echo "----------------------------------------------------------------------"
gcloud iam service-accounts create bigquery-qwiklab --display-name "my service account"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member=serviceAccount:bigquery-qwiklab@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/bigquery.dataViewer

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member=serviceAccount:bigquery-qwiklab@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/bigquery.user

echo "----------------------------------------------------------------------"
echo "                       Create a VM instance"
echo "----------------------------------------------------------------------"
gcloud compute instances create bigquery-instance \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --service-account=bigquery-qwiklab@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform

sleep 15

echo "----------------------------------------------------------------------"
echo "            Put the example code on a Compute Engine instance"
echo "----------------------------------------------------------------------"
cat > setup.sh << EOF
sudo apt install python3 python3-pip python3.11-venv -y
python3 -m venv myvenv
source myvenv/bin/activate
sudo apt-get update
sudo apt-get install -y git python3-pip
pip3 install --upgrade pip
pip3 install google-cloud-bigquery pyarrow pandas db-dtypes

cat > query.py << EOF_query
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(
    service_account_email='YOUR_SERVICE_ACCOUNT')

query = '''
SELECT
  year,
  COUNT(1) as num_babies
FROM
  publicdata.samples.natality
WHERE
  year > 2000
GROUP BY
  year
'''

client = bigquery.Client(
    project='Your Project ID',
    credentials=credentials)
print(client.query(query).to_dataframe())
EOF_query

sed -i -e "s/Your Project ID/$DEVSHELL_PROJECT_ID/g" query.py
sed -i -e "s/YOUR_SERVICE_ACCOUNT/bigquery-qwiklab@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com/g" query.py

python3 query.py

EOF

gcloud compute ssh bigquery-instance \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./setup.sh


echo "======================================================================"
echo "                            JOB is DONE !"
echo "======================================================================"