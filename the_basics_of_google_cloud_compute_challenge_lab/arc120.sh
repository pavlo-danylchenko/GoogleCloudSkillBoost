#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo "ZONE = $ZONE"

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                    Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID-bucket --location=US


echo "======================================================================"
echo "Task 2. Create and attach a persistent disk to a Compute Engine instance"
echo "======================================================================"
gcloud compute instances create my-instance \
    --zone $ZONE \
    --machine-type=e2-medium \
    --tags=http-server


echo "======================================================================"
echo "                     Create a new persistent disk"
echo "======================================================================"
gcloud compute disks create mydisk --size=200GB --zone $ZONE


echo "======================================================================"
echo "                         Attaching a disk"
echo "======================================================================"
gcloud compute instances attach-disk my-instance --disk=mydisk --zone $ZONE


echo "======================================================================"
echo "                      Task 3. Install a NGINX web server"
echo "======================================================================"
gcloud compute ssh my-instance --zone=$ZONE --quiet \
    --command="sudo apt-get update && sudo apt-get install -y nginx \
    && ps auwx | grep nginx"


echo "======================================================================"
echo "                         JOB is DONE!"
echo "======================================================================"