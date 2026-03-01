#!/bin/bash

echo "======================================================================"
echo "                            Clone demo"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/gke-tracing-demo
cd gke-tracing-demo

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



echo "======================================================================"
echo "                       Task 1. Initialization"
echo "======================================================================"
cd terraform

cat > provider.tf << EOF
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.84.0" 
    }
  }
}
provider "google" {
  project = var.project
}
EOF

terraform init
../scripts/generate-tfvars.sh

echo "======================================================================"
echo "                       Task 2. Deployment"
echo "======================================================================"
terraform plan
terraform apply -auto-approve


echo "======================================================================"
echo "                    Task 3. Deploy demo application"
echo "======================================================================"
kubectl apply -f tracing-demo-deployment.yaml

echo http://$(kubectl get svc tracing-demo -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


echo "======================================================================"
echo "                       Task 4. Validation"
echo "======================================================================"
# Waiting until LoadBalancer gets IP and save it in a variable
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  echo "Waiting for the IP for tracing-demo..."
  EXTERNAL_IP=$(kubectl get service tracing-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$EXTERNAL_IP" ] && sleep 10
done

echo "Endpoint: http://$EXTERNAL_IP"

curl -s "http://$EXTERNAL_IP"
echo -e "\n--- Default request sent ---"

curl -s "http://$EXTERNAL_IP/?string=CustomMessage"
echo -e "\n--- CustomMessage sent ---"

messages=("CloudTracing" "GKE_Demo" "Kubernetes_Rocks")

for msg in "${messages[@]}"
do
    curl -s "http://$EXTERNAL_IP/?string=$msg"
    echo -e "\n--- Message '$msg' sent ---"
done

echo "----------------------------------------------------------------------"
echo "                     Pulling Pub/Sub messages"
echo "----------------------------------------------------------------------"
gcloud pubsub subscriptions pull --auto-ack --limit 10 tracing-demo-cli


echo "======================================================================"
echo "       Task 5. Troubleshooting in your own environment (Optional)"
echo "======================================================================"
kubectl get deployment tracing-demo
kubectl describe deployment tracing-demo
kubectl get pod
kubectl describe pod tracing-demo


echo "======================================================================"
echo "                          Task 6. Teardown"
echo "======================================================================"
# terraform destroy


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"
