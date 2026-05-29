#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
gcloud services enable cloudbuild.googleapis.com container.googleapis.com

read -p "Enter the Monolith Identifier: " MONOLITH_IDENTIFIER
read -p "Enter the Cluster Name: " CLUSTER_NAME
read -p "Enter the Orders Identifier: " ORDERS_IDENTIFIER
read -p "Enter the Products Identifier: " PRODUCTS_IDENTIFIER
read -p "Enter the Frontend Identifier: " FRONTEND_IDENTIFIER

# export PROJECT_ID=$(gcloud config get project)
# export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "    Task 1. Download the monolith code and build your container"
echo "======================================================================"
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/$MONOLITH_IDENTIFIER:1.0.0 .


echo "======================================================================"
echo "    Task 2. Create a kubernetes cluster and deploy the application"
echo "======================================================================"
gcloud container clusters create $CLUSTER_NAME --num-nodes 3 --machine-type=e2-medium

kubectl create deployment $MONOLITH_IDENTIFIER --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$MONOLITH_IDENTIFIER:1.0.0
kubectl expose deployment $MONOLITH_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8080


echo "======================================================================"
echo "               Task 3. Create new microservices"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "         Create a containerized version of your microservices"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/microservices/src/orders
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/$ORDERS_IDENTIFIER:1.0.0 .

cd ~/monolith-to-microservices/microservices/src/products
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/$PRODUCTS_IDENTIFIER:1.0.0 .


echo "======================================================================"
echo "               Task 4. Deploy the new microservices"
echo "======================================================================"
kubectl create deployment $ORDERS_IDENTIFIER --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$ORDERS_IDENTIFIER:1.0.0
kubectl expose deployment $ORDERS_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8081

kubectl create deployment $PRODUCTS_IDENTIFIER --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$PRODUCTS_IDENTIFIER:1.0.0
kubectl expose deployment $PRODUCTS_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8082


echo "======================================================================"
echo "        Task 5. Configure and deploy the Frontend microservice"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                      Reconfigure Frontend"
echo "----------------------------------------------------------------------"


echo "======================================================================"
echo "  Task 6. Create a containerized version of the Frontend microservice"
echo "======================================================================"
cd ~/monolith-to-microservices/microservices/src/frontend

gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/$FRONTEND_IDENTIFIER:1.0.0 .
kubectl create deployment $FRONTEND_IDENTIFIER --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$FRONTEND_IDENTIFIER:1.0.0
kubectl expose deployment $FRONTEND_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8080

echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"