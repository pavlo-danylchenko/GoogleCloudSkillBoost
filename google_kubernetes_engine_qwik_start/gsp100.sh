#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)


echo "======================================================================"
echo "                Task 1. Set a default compute zone"
echo "======================================================================"
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                  Task 2. Create a GKE cluster"
echo "======================================================================"
gcloud container clusters create --machine-type=e2-medium --zone=$ZONE lab-cluster


echo "======================================================================"
echo "         Task 3. Get authentication credentials for the cluster"
echo "======================================================================"
gcloud container clusters get-credentials lab-cluster


echo "======================================================================"
echo "            Task 4. Deploy an application to the cluster"
echo "======================================================================"
kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment hello-server --type=LoadBalancer --port 8080
sleep 5

export EXTERNAL_IP=$(kubectl get svc hello-server -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP is: $EXTERNAL_IP"

curl -s http://$EXTERNAL_IP:8080

read -p "Check the progress to verify the objective and Press [Enter] key to continue..."


echo "======================================================================"
echo "                     Task 5. Delete the cluster"
echo "======================================================================"
gcloud container clusters delete lab-cluster --quiet


echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"