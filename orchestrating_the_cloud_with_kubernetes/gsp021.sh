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
echo "----------------------------------------------------------------------"
echo "           Start up a cluster for use in this lab"
echo "----------------------------------------------------------------------"
gcloud container clusters create io --zone $ZONE

echo "======================================================================"
echo "                Task 1. Get the sample code"
echo "======================================================================"
gcloud storage cp -r gs://spls/gsp021/* .
cd orchestrate-with-kubernetes/kubernetes


echo "======================================================================"
echo "                Task 2. A quick Kubernetes demo"
echo "======================================================================"
kbectl create deployment nginx --image=nginx:1.27.0
kubectl get pods
kubectl expose deployment nginx --port=80 --type=LoadBalancer

echo "----------------------------------------------------------------------"
echo "                           Get services"
echo "----------------------------------------------------------------------"
kubectl get services

echo "======================================================================"
echo "                    Task 4. Create Pods"
echo "======================================================================"
kubectl create -f pods/fortune-app.yaml
kubectl get pods

echo "======================================================================"
echo "                    Task 7. Create a Service"
echo "======================================================================"
kubectl create secret generic tls-certs --from-file tls/
kubectl create configmap nginx-proxy-conf --from-file nginx/proxy.conf
kubectl create -f pods/secure-fortune.yaml
kubectl create -f services/fortune-app.yaml

gcloud compute firewall-rules create allow-fortune-nodeport --allow tcp:31000


echo "======================================================================"
echo "                    Task 8. Add labels to Pods"
echo "======================================================================"
kubectl label pods secure-fortune 'secure=enabled'
kubectl get pods secure-fortune --show-labels
kubectl describe services fortune-app | grep Endpoints

echo "======================================================================"
echo "                    Task 10. Create Deployments"
echo "======================================================================"
kubectl create -f deployments/auth.yaml
kubectl create -f services/auth.yaml
kubectl create -f deployments/fortune-service.yaml
kubectl create -f services/fortune-service.yaml
kubectl create configmap nginx-frontend-conf --fromfile=nginx/frontend.conf
kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml

echo "Job is Done!"