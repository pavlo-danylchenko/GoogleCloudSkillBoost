#!/bin/bash
set -euo pipefail

# Implement DevOps Workflows in Google Cloud: Challenge Lab

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                  Task 1. Create the lab resources"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                Set PROJECT_ID and PROJECT_NUMBER"
echo "----------------------------------------------------------------------"
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export GIT_SERVER_IP=$(gcloud compute instances describe git-server \
    --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Git Server IP is: ${GIT_SERVER_IP}"


echo "----------------------------------------------------------------------"
echo "Enable the APIs for GKE, Cloud Build, Secret Manager and Artifact Analysis"
echo "----------------------------------------------------------------------"
# gcloud services enable container.googleapis.com \
#     cloudbuild.googleapis.com \
#     secretmanager.googleapis.com \
#     containeranalysis.googleapis.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$(gcloud projects describe $PROJECT_ID \
    --format="value(projectNumber)")@cloudbuild.gserviceaccount.com --role="roles/container.developer"


echo "----------------------------------------------------------------------"
echo "              Configure Git and GitHub in Cloud Shell"
echo "----------------------------------------------------------------------"
git config --global user.name "Student"
git config --global user.email "student@qwiklabs.net"


echo "----------------------------------------------------------------------"
echo "            Create an Artifact Registry Docker repository"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$REGION


echo "----------------------------------------------------------------------"
echo "   Create a GKE cluster to deploy the sample application"
echo "----------------------------------------------------------------------"
gcloud container clusters create hello-cluster \
    --zone="$ZONE" \
    --release-channel=regular \
    --cluster-version=latest \
    --num-nodes=3 \
    --enable-autoscaling \
    --min-nodes=2 \
    --max-nodes=6

gcloud container clusters get-credentials hello-cluster \
    --zone=$ZONE

kubectl create ns prod
kubectl create ns dev


echo "======================================================================"
echo "     Task 2. Connect to the Git repository on the Git server"
echo "======================================================================"
cd ~
mkdir sample-app
gcloud storage cp -r gs://spls/gsp330/sample-app/* sample-app

for file in sample-app/cloudbuild-dev.yaml sample-app/cloudbuild.yaml; do
    sed -i "s/<your-region>/${REGION}/g" "$file"
    sed -i "s/<your-zone>/${ZONE}/g" "$file"
    sed -i "s/<version>/v1.0/g" "$file"
done
# </version></your-zone></your-region>


cd ~/sample-app
git init
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git
git branch -m master
git add . && git commit -m "initial commit"
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git master


cd ~/sample-app
git checkout -b dev
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git dev

echo "======================================================================"
echo "               Task 3. Create the Cloud Build Triggers"
echo "======================================================================"
gcloud builds triggers create manual \
   --name="sample-app-prod-deploy" \
   --inline-config="cloudbuild.yaml" \
   --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
   --region=$REGION


gcloud builds triggers create manual \
   --name="sample-app-dev-deploy" \
   --inline-config="cloudbuild-dev.yaml" \
   --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
   --region=$REGION


echo "======================================================================"
echo "        Task 4. Deploy the first versions of the application"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "               Build the first development deployment"
echo "----------------------------------------------------------------------"
sed -i "s|<todo>|$REGION-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild-dev:v1.0|g" \
    dev/deployment.yaml

git checkout dev
git add .
git commit -m "Deploy v1.0 on dev"
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git dev

gcloud builds submit --config=cloudbuild-dev.yaml .

kubectl expose deployment development-deployment \
    --namespace=dev \
    --name=dev-deployment-service \
    --type=LoadBalancer \
    --port=8080 \
    --target-port=8080


echo "----------------------------------------------------------------------"
echo "               Build the first production deployment"
echo "----------------------------------------------------------------------"
sed -i "s|<todo>|$REGION-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:v1.0|g" \
    prod/deployment.yaml

git checkout master
git add .
git commit -m "Deploy v1.0 on master"
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git master

gcloud builds submit --config=cloudbuild.yaml .

kubectl expose deployment production-deployment \
    --namespace=prod \
    --name=prod-deployment-service \
    --type=LoadBalancer \
    --port=8080 \
    --target-port=8080


read -p "CHECK the TASK #4 status and PRESS ANY KEY..." 

echo "======================================================================"
echo "          Task 5. Deploy the second versions of the application"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "               Build the second development deployment"
echo "----------------------------------------------------------------------"

echo "----------------------------------------------------------------------"
echo ""
echo "               PERFORM SECOND EPLOYMENT MANUALLY"
echo ""
echo "----------------------------------------------------------------------"


echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"