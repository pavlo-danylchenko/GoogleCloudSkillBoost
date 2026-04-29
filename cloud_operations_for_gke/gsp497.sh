#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 1. Set region/zone"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                      Task 2. Clone demo"
echo "======================================================================"
gsutil cp gs://spls/gsp497/gke-monitoring-tutorial.zip .
unzip gke-monitoring-tutorial.zip
cd gke-monitoring-tutorial

read -p "Click Navigation menu -> View All Products -> Observability -> Monitoring. Then press ENTER..."

make create


echo "======================================================================"
echo "                      Task 3. Validation"
echo "======================================================================"
make validate


echo "======================================================================"
echo "                      Task 4. Teardown"
echo "======================================================================"
read -p "CHECK the progress and hit ENTER to teardown the environment..."
make teardown


echo "======================================================================"
echo "                      JOB is DONE !!!"
echo "======================================================================"