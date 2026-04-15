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
echo "                 Task 1. Create a Kubernetes cluster"
echo "======================================================================"
gcloud container clusters create echo-cluster --num-nodes 2 --zone=$ZONE --machine-type=e2-standard-2


echo "======================================================================"
echo "                 Task 2. Build a tagged Docker image"
echo "======================================================================"
gsutil cp gs://$DEVSHELL_PROJECT_ID/echo-web.tar.gz .
tar -xvf echo-web.tar.gz
cd ech-web
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/echo-app:v1 .

echo "======================================================================"
echo "        Task 3. Push the image to the Google Container Registry"
echo "======================================================================"


echo "======================================================================"
echo "       Task 4. Deploy the application to the Kubernetes cluster"
echo "======================================================================"
kubectl create deployment echo-web --image=gcr.io/$DEVSHELL_PROJECT_ID/echo-app:v1
kubectl expose deployment echo-web --type=LoadBalancer --port=80 --target-port=8000
kubectl get svc
