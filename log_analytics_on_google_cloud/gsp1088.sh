#!/bin/bash

echo "Starting Execution"


# Task 1. Infrastructure setup
export REGION=$(gcloud container clusters list --format='value(LOCATION)')
# Get the cluster credentials:
gcloud container clusters get-credentials day2-ops --region $REGION


# Task 2. Deploy the application
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo
# Install the app using kubectl
kubectl apply -f release/kubernetes-manifests.yaml

sleep 50

# Get the external IP of the application
export EXTERNAL_IP=$(kubectl get service frontend-external -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo $EXTERNAL_IP

curl -o /dev/null -s -w "%{http_code}\n"  http://${EXTERNAL_IP}


# Task 3. Manage log buckets
gcloud logging buckets update _Default \
    --location=global \
    --enable-analytics

gcloud logging sinks create day2ops-sink \
    logging.googleapis.com/projects/$DEVSHELL_PROJECT_ID/locations/global/buckets/day2ops-log \
    --log-filter='resource.type="k8s_container"' \
    --include-children \
    --format='json'

echo "Click here: https://console.cloud.google.com/logs/storage/bucket?project=$DEVSHELL_PROJECT_ID"
