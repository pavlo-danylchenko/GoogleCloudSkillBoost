#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create a cluster"
echo "======================================================================"
gcloud config set dataproc/region $REGION
gcloud services disable dataproc.googleapis.com --force
gcloud services enable dataproc.googleapis.com


export PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')
export SA_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/dataproc.worker"
sleep 5

gcloud compute networks subnets update default \
    --region=$REGION  \
    --enable-private-ip-google-access

gcloud dataproc clusters create example-cluster \
    --region=$REGION \
    --zone=$ZONE \
    --master-boot-disk-type=pd-standard \
    --master-boot-disk-size=30G \
    --master-machine-type=e2-standard-4 \
    --num-workers=2 \
    --worker-boot-disk-type=pd-standard \
    --worker-machine-type=e2-standard-4 \
    --worker-boot-disk-size=30G \
    --public-ip-address \
    --project=$GOOGLE_CLOUD_PROJECT


echo "======================================================================"
echo "                       Task 2. Submit a job"
echo "======================================================================"

gcloud dataproc jobs submit spark --cluster=example-cluster \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPi \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    -- 1000

echo "======================================================================"
echo "                      Task 3. Update a cluster"
echo "======================================================================"
gcloud dataproc clusters update example-cluster \
    --region=$REGION \
    --num-workers=4


gcloud dataproc clusters update example-cluster \
    --region=$REGION \
    --num-workers=2

echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"