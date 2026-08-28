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

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "----------------------------------------------------------------------"
echo "                   Get sample code for this lab"
echo "----------------------------------------------------------------------"
gcloud storage cp -r gs://spls/gsp053/kubernetes .
cd kubernetes

gcloud container clusters create bootcamp \
    --machine-type e2-small \
    --num-nodes 3 \
    --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"


echo "======================================================================"
echo "            Task 1. Learn about the deployment object"
echo "======================================================================"
# kubectl explain deployment
# kubectl explain deployment --recursive
# kubectl explain deployment.metadata.name


echo "======================================================================"
echo "                  Task 2. Create a deployment"
echo "======================================================================"
# cat deployments/fortune-app-blue.yaml
kubectl create -f deployments/fortune-app-blue.yaml
# kubectl get deployments
# kubectl get replicasets
# kubectl get pods
kubectl create -f services/fortune-app.yaml
# kubectl get services fortune-app

curl "http://$(kubectl get svc fortune-app -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')/version" || :

# kubectl scale deployment fortune-app-blue --replicas=5
# kubectl get pods | grep fortune-app-blue | wc -l
# kubectl scale deployment fortune-app-blue --replicas=3
# kubectl get pods | grep fortune-app-blue | wc -l

read -p "Check the TASK #2 status and press ANY KEY to proceed to the next task..."

echo "======================================================================"
echo "                      Task 3. Rolling update"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                      Trigger a rolling update"
echo "----------------------------------------------------------------------"
# kubectl set image deployment/fortune-app-blue \
#     fortune-app=$REGION-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0

# kubectl set env deployment/fortune-app-blue APP_VERSION=2.0.0

# kubectl get replicaset
# kubectl rollout history deployment/fortune-app-blue


echo "----------------------------------------------------------------------"
echo "                      Pause a rolling update"
echo "----------------------------------------------------------------------"
# kubectl rollout pause deployment/fortune-app-blue
# kubectl rollout status deployment/fortune-app-blue


echo "----------------------------------------------------------------------"
echo "                      Resume a rolling update"
echo "----------------------------------------------------------------------"
# kubectl rollout resume deployment/fortune-app-blue
# kubectl rollout status deployment/fortune-app-blue


echo "----------------------------------------------------------------------"
echo "                      Roll back an update"
echo "----------------------------------------------------------------------"
# kubectl rollout undo deployment/fortune-app-blue
# curl http://`kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version || true


echo "======================================================================"
echo "                      Task 4. Canary deployments"
echo "======================================================================"
kubectl create -f deployments/fortune-app-canary.yaml

for i in {1..10}; do curl -s http://`kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version || true; echo;
done

read -p "Check the TASK #4 status and press ANY KEY to proceed to the next task..."


echo "======================================================================"
echo "                      Task 5. Blue-green deployments"
echo "======================================================================"
kubectl apply -f services/fortune-app-blue-service.yaml
kubectl create -f deployments/fortune-app-green.yaml
# curl http://`kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version

kubectl apply -f services/fortune-app-green-service.yaml
# curl http://`kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version

kubectl apply -f services/fortune-app-blue-service.yaml
# curl http://`kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"