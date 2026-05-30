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
echo "                Task 1. Clone the source repository"
echo "======================================================================"
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh
cd ~/monolith-to-microservices/monolith


echo "======================================================================"
echo "           Task 2. Create a Docker container with Cloud Build"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                 Create the target Docker repository"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create monolith-demo \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Container Dev Workshop"


echo "----------------------------------------------------------------------"
echo "                     Configure authentication"
echo "----------------------------------------------------------------------"
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet


echo "----------------------------------------------------------------------"
echo "                       Deploy the image"
echo "----------------------------------------------------------------------"
gcloud services enable artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com

gcloud builds submit --tag $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0


echo "======================================================================"
echo "             Task 3. Deploy the container to Cloud Run"
echo "======================================================================"
gcloud run deploy monolith \
    --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
    --region $REGION \
    --quiet

echo "======================================================================"
echo "           Task 4. Create new revision with lower concurrency"
echo "======================================================================"
gcloud run deploy monolith \
    --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
    --region $REGION \
    --concurrency 1

read -p "Check the task progress and press [Enter] to continue..."

gcloud run deploy monolith \
    --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
    --region $REGION \
    --concurrency 80


echo "======================================================================"
echo "               Task 5. Make changes to the website"
echo "======================================================================"
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js

cd ~/monolith-to-microservices/react-app
npm run build:monolith

cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:2.0.0


echo "======================================================================"
echo "               Task 6. Update website with zero downtime"
echo "======================================================================"
gcloud run deploy monolith --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:2.0.0 \
    --region $REGION

echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"