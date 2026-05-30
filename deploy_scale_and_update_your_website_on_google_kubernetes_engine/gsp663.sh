#!/bin/bash

echo "================================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "================================================================================"

gcloud services enable cloudbuild.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "================================================================================"
echo "                Task 1. Create a GKE cluster"
echo "================================================================================"
gcloud container clusters create fancy-cluster --num-nodes=3


echo "================================================================================"
echo "                   Task 2. Clone source repository"
echo "================================================================================"
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

cd ~/monolith-to-microservices/monolith


echo "================================================================================"
echo "           Task 3. Create Docker container with Cloud Build"
echo "================================================================================"
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0 .


echo "================================================================================"
echo "                Task 4. Deploy container to GKE"
echo "================================================================================"

kubectl create deployment monolith --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0


echo "================================================================================"
echo "                Task 5. Expose GKE deployment"
echo "================================================================================"
kubectl expose deployment monolith --type=LoadBalancer --port=80 --target-port=8080


echo "================================================================================"
echo "                Task 6. Scale GKE deployment"
echo "================================================================================"
kubectl scale deployment monolith --replicas=3


echo "================================================================================"
echo "                Task 7. Make changes to the website"
echo "================================================================================"
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js

cd ~/monolith-to-microservices/react-app
npm run build:monolith

cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:2.0.0 .


echo "================================================================================"
echo "              Task 8. Update website with zero downtime"
echo "================================================================================"
kubectl set image deployment/monolith monolith=gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:2.0.0


echo "================================================================================"
echo "              Task 9. Cleanup (OPTIONAL)"
echo "================================================================================"
# cd ~
# rm -rf monolith-to-microservices
# Delete the container image for version 1.0.0 of the monolith
# gcloud container images delete gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0 --quiet

# Delete the container image for version 2.0.0 of the monolith
# gcloud container images delete gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:2.0.0 --quiet


# The following command will take all source archives from all builds and delete them from cloud storage

# Run this command to print all sources:
# gcloud builds list | awk 'NR > 1 {print $4}'

# gcloud builds list | grep 'SOURCE' | cut -d ' ' -f2 | while read line; do gsutil rm $line; done

# kubectl delete service monolith --quiet
# kubectl delete deployment monolith --quiet

# gcloud container clusters delete fancy-cluster lab region --quiet

echo "================================================================================"
echo "                          JOB is DONE !"
echo "================================================================================"