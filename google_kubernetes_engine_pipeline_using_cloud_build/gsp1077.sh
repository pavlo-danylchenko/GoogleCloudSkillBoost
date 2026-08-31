#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 1. Initialize your lab"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                Set PROJECT_ID and PROJECT_NUMBER"
echo "----------------------------------------------------------------------"

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo "----------------------------------------------------------------------"
echo "Enable the APIs for GKE, Cloud Build, Secret Manager and Artifact Analysis"
echo "----------------------------------------------------------------------"
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com

echo "----------------------------------------------------------------------"
echo "            Create an Artifact Registry Docker repository"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create my-repository \
    --repository-format=docker --location=$REGION

echo "----------------------------------------------------------------------"
echo "   Create a GKE cluster to deploy the sample application"
echo "----------------------------------------------------------------------"
gcloud container clusters create hello-cloudbuild --num-nodes=1 \
    --location=$REGION

echo "----------------------------------------------------------------------"
echo "              Configure Git and GitHub in Cloud Shell"
echo "----------------------------------------------------------------------"
curl -sS https://webi.sh/gh | sh 
gh auth login 
gh api user -q ".login"
GITHUB_USERNAME=$(gh api user -q ".login")
git config --global user.name "${GITHUB_USERNAME}"
git config --global user.email "${USER_EMAIL}"
echo ${GITHUB_USERNAME}
echo ${USER_EMAIL}

echo "======================================================================"
echo "       Task 2. Create the Git repositories in GitHub repositories"
echo "======================================================================"
gh repo create  hello-cloudbuild-app --private 
gh repo create  hello-cloudbuild-env --private
cd ~
mkdir hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app
cd ~/hello-cloudbuild-app

sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

git init
git config credential.helper gcloud.sh
git remote add google https://github.com/${GITHUB_USERNAME}/hello-cloudbuild-app
git branch -m master
git add . && git commit -m "initial commit"

echo "======================================================================"
echo "          Task 3. Create a container image with Cloud Build"
echo "======================================================================"
cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .


echo "======================================================================"
echo "         Task 4. Create the Continuous Integration (CI) pipeline"
echo "======================================================================"


export REGION=us-east4
gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
    --project=$DEVSHELL_PROJECT_ID \
    --location=$REGION \
    --data-source-resource="//bigquery.googleapis.com/projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
    --data-quality-spec-file="gs://$DEVSHELL_PROJECT_ID-dq-config/dq-customer-orders.yaml"



echo "======================================================================"
echo "                     Task 1. Viewing networks"
echo "======================================================================"
echo "======================================================================"
echo "                     Task 1. Viewing networks"
echo "======================================================================"
echo "======================================================================"
echo "                     Task 1. Viewing networks"
echo "======================================================================"
echo "======================================================================"
echo "                     Task 1. Viewing networks"
echo "======================================================================"
ssh-keygen -t rsa -b 4096 -N '' -f id_github -C danilchenko@ukr.net