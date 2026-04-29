#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 0. Set region/zone/environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                 Task 1. Perform infrastructure setup"
echo "======================================================================"
gcloud services enable cloudaicompanion.googleapis.com
gcloud container clusters list


echo "======================================================================"
echo "                   Task 2. Deploy an application"
echo "======================================================================"
git clone https://github.com/xiangshen-dk/microservices-demo.git
cd microservices-demo

gcloud container clusters get-credentials central --zone $ZONE
kubectl apply -f release/kubernetes-manifests.yaml

kubectl get nodes

export EXTERNAL_IP=$(kubectl get service frontend-external | awk 'BEGIN { cnt=0; } { cnt+=1; if (cnt > 1) print $4; }')
curl -o /dev/null -s -w "%{http_code}\n"  http://$EXTERNAL_IP


echo "======================================================================"
echo "                 Task 4. Create a logs-based metric"
echo "======================================================================"
read -p "Complete task manually and press ENTER to continue..."

echo "======================================================================"
echo "                       JOB is DONE !!!"
echo "======================================================================"