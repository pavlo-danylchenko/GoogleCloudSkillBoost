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


echo "======================================================================"
echo "                Task 1. Creating a cluster"
echo "======================================================================"
gcloud container clusters create hello-world --zone $ZONE


echo "======================================================================"
echo "           Task 2. Building and publishing the Hello World app"
echo "======================================================================"
echo $DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "                 Task 3. Get the sample code"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/kubernetes-engine-samples
cd kubernetes-engine-samples/quickstarts/hello-app

echo "----------------------------------------------------------------------"
echo "                       Build the container"
echo "----------------------------------------------------------------------"
docker build -t gcr.io/$DEVSHELL_PROJECT_ID/hello-app:1.0 .

echo "----------------------------------------------------------------------"
echo "                       Publish the container"
echo "----------------------------------------------------------------------"
gcloud docker -- push gcr.io/$DEVSHELL_PROJECT_ID/hello-app:1.0


echo "======================================================================"
echo "                Task 4. Deploying the Hello World app"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                       Create your deployment"
echo "----------------------------------------------------------------------"
kubectl create deployment hello-app --image=gcr.io/$DEVSHELL_PROJECT_ID/hello-app:1.0

echo "----------------------------------------------------------------------"
echo "                       Get deployment"
echo "----------------------------------------------------------------------"
kubectl get deployments

echo "----------------------------------------------------------------------"
echo "                       Get PODs"
echo "----------------------------------------------------------------------"
kubectl get pods

echo "----------------------------------------------------------------------"
echo "                       Allow external traffic"
echo "----------------------------------------------------------------------"
kubectl expose deployment hello-app --name=hello-app--type=LoadBalancer --port 80 --target-port 8080

echo "----------------------------------------------------------------------"
echo "                       Verify the deployment"
echo "----------------------------------------------------------------------"
# export EXTERNAL_IP=$(kubectl get services hello-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# curl http://$EXTERNAL_IP

echo "JOB is DONE !"