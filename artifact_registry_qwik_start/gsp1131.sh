#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

sleep 10

echo "======================================================================"
echo "                Task 1. Create a Docker repository"
echo "======================================================================"
gcloud artifacts repositories create example-docker-repo \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository" \
    --project=$DEVSHELL_PROJECT_ID


gclou artifacts repositories list \
    --project=$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "        Task 2. Configure authentication for Artifact Registry"
echo "======================================================================"
gcloud auth configure-docker $REGION-docker.pkg.dev

echo "======================================================================"
echo "                  Task 3. Obtain an image to push"
echo "======================================================================"
docker pull us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0

echo "======================================================================"
echo "                Task 4. Add the image to the repository"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                Tag the image with a registry name"
echo "----------------------------------------------------------------------"
docker tag us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0 \
    $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/example-docker-repo/sample-image:tag1

echo "----------------------------------------------------------------------"
echo "                Push the image to Artifact Registry"
echo "----------------------------------------------------------------------"
docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/example-docker-repo/sample-image:tag1

echo "======================================================================"
echo "               Task 5. Pull the image from Artifact Registry"
echo "======================================================================"
docker pull $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/example-docker-repo/sample-image:tag1


echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"