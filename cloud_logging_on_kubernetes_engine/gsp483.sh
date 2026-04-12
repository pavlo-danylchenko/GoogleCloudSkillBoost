#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo "ZONE = $ZONE"

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# read -p "Enter the name of the default Load Balancer: " FORWARDING_RULE

echo "======================================================================"
echo "                     Task 1. Clone the demo code"
echo "======================================================================"
gcloud config set project $DEVSHELL_PROJECT_ID

git clone https://github.com/GoogleCloudPlatform/gke-logging-sinks-demo
cd gke-logging-sinks-demo


echo "======================================================================"
echo "                  Task 2. Deploy the infrastructure"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                  Update the provider.tf file"
echo "----------------------------------------------------------------------"
sed -i 's/version = "~> 2.11.0"/version = "~> 2.19.0"/g' terraform/provider.tf


echo "----------------------------------------------------------------------"
echo "                      Deploying the cluster"
echo "----------------------------------------------------------------------"
sed -i 's/resource.type = container/resource.type = k8s_container/g' terraform/main.tf
make create


echo "======================================================================"
echo "                        Task 3. Validation"
echo "======================================================================"
make validate


echo "======================================================================"
echo "                       Task 4. Generating logs"
echo "======================================================================"
# export IP_ADDRESS=$(gcloud compute forwarding-rules describe $FORWARDING_RULE --global --format="value(IPAddress)")
# export PORT=$(gcloud compute forwarding-rules describe $FORWARDING_RULE --global --format='value(portRange)')

read IP_ADDRESS PORT <<< $(gcloud compute forwarding-rules list --format="value(IPAddress,portRange)" --limit=1)
export PORT=$(echo $PORT | cut -d '-' -f 1)

echo "Target URL is: http://$IP_ADDRESS:$PORT"

if [ -z "$IP_ADDRESS" ]; then
    echo "ERROR: Load Balacer not found."
else
    for i in {1..5}
    do
        curl -v "http://$IP_ADDRESS:$PORT"
    done
fi

echo "======================================================================"
echo "                    Task 5. View logs in Cloud Logging"
echo "======================================================================"
gcloud logging read "resource.type=k8s_container AND resource.labels.cluster_name=stackdriver-logging" \
    --project=$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "                   Task 8. View logs in BigQuery"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
SELECT *
FROM \`$DEVSHELL_PROJECT_ID.gke_logs_dataset.diagnostic_log_*\`
WHERE _TABLE_SUFFIX BETWEEN
FORMAT_DATE('%Y%m%d', CURRENT_DATE() - INTERVAL 1 DAY)
AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
"

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"