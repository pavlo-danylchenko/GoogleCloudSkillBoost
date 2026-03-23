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
echo "                     Task 1. Create a cluster"
echo "======================================================================"

gcloud dataproc clusters create example-cluster \
    --region=$REGION \
    --zone=$ZONE \
    --master-boot-disk-type=pd-standard \
    --master-boot-disk-size=30GB \
    --master-machine-type=e2-standard-2 \
    --num-workers=2 \
    --worker-boot-disk-type=pd-standard \
    --worker-machine-type=e2-standard-2 \
    --worker-boot-disk-size=30GB \
    --no-address=false \
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
echo "                    Task 3. View the job output"
echo "======================================================================"
read -p "CHECK PROGRESS BEFORE CONTINUENING and PRESS ENTER..."

echo "======================================================================"
echo "       Task 4. Update a cluster to modify the number of workers"
echo "======================================================================"
gcloud dataproc clusters update example-cluster \
    --region=$REGION \
    --num-workers=4

gcloud dataproc jobs submit spark --cluster=example-cluster \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPi \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    -- 1000


echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"