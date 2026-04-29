#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 1. Set project and zone"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")


export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


export PROJECT=$DEVSHELL_PROJECT_ID
export CLUSTER=gke-load-test
export TARGET=${PROJECT}.appspot.com


echo "======================================================================"
echo "Task 2. Get the sample code and build a Docker image for the application"
echo "======================================================================"
gsutil -m cp -r gs://spls/gsp182/distributed-load-testing-using-kubernetes .
cd distributed-load-testing-using-kubernetes/sample-webapp/
sed -i "s/python37/python312/g" app.yaml
cd ..
gcloud builds submit --tag gcr.io/$PROJECT/locust-tasks:latest docker-image/.


echo "======================================================================"
echo "                  Task 3. Deploy web application"
echo "======================================================================"
gcloud app deploy sample-webapp/app.yaml


echo "======================================================================"
echo "                  Task 4. Deploy Kubernetes cluster"
echo "======================================================================"
gcloud container clusters create $CLUSTER \
    --zone $ZONE \
    --num-nodes=5


echo "======================================================================"
echo "                  Task 6. Deploy locust-master"
echo "======================================================================"
sed -i -e "s/\[TARGET_HOST\]/$TARGET/g" kubernetes-config/locust-master-controller.yaml
sed -i -e "s/\[TARGET_HOST\]/$TARGET/g" kubernetes-config/locust-worker-controller.yaml
sed -i -e "s/\[PROJECT_ID\]/$PROJECT/g" kubernetes-config/locust-master-controller.yaml
sed -i -e "s/\[PROJECT_ID\]/$PROJECT/g" kubernetes-config/locust-worker-controller.yaml

kubectl apply -f kubernetes-config/locust-master-controller.yaml
kubectl get pods -l app=locust-master

kubectl apply -f kubernetes-config/locust-master-service.yaml

kubectl get svc locust-master


echo "======================================================================"
echo "                  Task 7. Load testing workers"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                       Deploy locust-worker"
echo "----------------------------------------------------------------------"
kubectl apply -f kubernetes-config/locust-worker-controller.yaml
kubectl get pods -l app=locust-worker

kubectl scale deployment/locust-worker --replicas=20
kubectl get pods -l app=locust-worker

echo "======================================================================"
echo "                       Task 8. Execute tests"
echo "======================================================================"
EXTERNAL_IP=$(kubectl get svc locust-master -o yaml | grep ip: | awk -F": " '{print $NF}')
echo http://$EXTERNAL_IP:8089


echo "======================================================================"
echo "                       JOB is DONE !!!"
echo "======================================================================"