#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "               Task 1. Prepare the lab environment"
echo "======================================================================"


echo "----------------------------------------------------------------------"
echo "                        Set up variables"
echo "----------------------------------------------------------------------"

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')


echo "----------------------------------------------------------------------"
echo "                        Enable Google services"
echo "----------------------------------------------------------------------"

gcloud services enable \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  containerregistry.googleapis.com \
  containerscanning.googleapis.com


echo "----------------------------------------------------------------------"
echo "                        Get the source code"
echo "----------------------------------------------------------------------"
git clone https://github.com/GoogleCloudPlatform/cloud-code-samples/
cd ~/cloud-code-samples


echo "----------------------------------------------------------------------"
echo "              Provision the infrastructure used in this lab"
echo "----------------------------------------------------------------------"
gcloud container clusters create container-dev-cluster --zone=$ZONE


echo "======================================================================"
echo "               Task 2. Working with container images"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "              Create a Docker Repository on Artifact registry"
echo "----------------------------------------------------------------------"

gcloud artifacts repositories create container-dev-repo --repository-format=docker \
  --location=$REGION \
  --description="Docker repository for Container Dev Workshop"

echo "----------------------------------------------------------------------"
echo "          Configure Docker Authentication to Artifact Registry"
echo "----------------------------------------------------------------------"
gcloud auth configure-docker $REGION-docker.pkg.dev


echo "----------------------------------------------------------------------"
echo "                 Explore the sample Application"
echo "----------------------------------------------------------------------"
cd ~/cloud-code-samples/java/java-hello-world

echo "----------------------------------------------------------------------"
echo "                 Build the Container Image"
echo "----------------------------------------------------------------------"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/container-dev-repo/java-hello-world:tag1 .


echo "----------------------------------------------------------------------"
echo "            Push the Container Image to Artifact Registry"
echo "----------------------------------------------------------------------"
docker push $REGION-docker.pkg.dev/$PROJECT_ID/container-dev-repo/java-hello-world:tag1


echo "======================================================================"
echo "               Task 3. Integration with Cloud Code"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "         Deploy the Application to GKE Cluster from Cloud Code"
echo "----------------------------------------------------------------------"
cd ~/cloud-code-samples/
cloudshell workspace .


echo "======================================================================"
echo "                      FIRST PART is DONE !"
echo "======================================================================"