#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 1. Set the region and zone"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                     Task 2. Creating a private cluster"
echo "======================================================================"
gcloud beta container clusters create private-cluster \
    --enable-private-nodes \
    --master-ipv4-cidr 172.16.0.16/28 \
    --enable-ip-alias \
    --create-subnetwork ""


echo "======================================================================"
echo "                  Task 4. Enable master authorized networks"
echo "======================================================================"
gcloud compute instances create source-instance --zone=$ZONE --scopes 'https://www.googleapis.com/auth/cloud-platform'
# gcloud compute instances describe source-instance --zone=$ZONE | grep natIP

EXTERNAL_IP=$(gcloud compute instances describe source-instance \
    --zone=$ZONE \
    --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

gcloud container clusters update private-cluster \
    --enable-master-authorized-networks \
    --master-authorized-networks $EXTERNAL_IP/32

#                                   OPTIONAL
# echo "----------------------------------------------------------------------"
# echo "                    SSH into source-instance with:"
# echo "----------------------------------------------------------------------"
# gcloud compute ssh source-instance --zone=$ZONE
# sudo apt-get install kubectl

# sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
# gcloud container clusters get-credentials private-cluster --zone=$ZONE
# kubectl get nodes --output yaml | grep -A4 addresses


echo "======================================================================"
echo "                     Task 5. Clean Up"
echo "======================================================================"
# sleep 60
gcloud container clusters delete private-cluster --zone=$ZONE

echo "======================================================================"
echo "     Task 6. Create a private cluster that uses a custom subnetwork"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                Create a subnetwork and secondary ranges"
echo "----------------------------------------------------------------------"

gcloud compute networks subnets create my-subnet \
    --network default \
    --range 10.0.4.0/22 \
    --enable-private-ip-google-access \
    --region=$REGION \
    --secondary-range my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14

echo "----------------------------------------------------------------------"
echo "          Create a private cluster that uses your subnetwork"
echo "----------------------------------------------------------------------"

gcloud beta container clusters create private-cluster2 \
    --enable-private-nodes \
    --enable-ip-alias \
    --master-ipv4-cidr 172.16.0.32/28 \
    --subnetwork my-subnet \
    --services-secondary-range-name my-svc-range \
    --cluster-secondary-range-name my-pod-range \
    --zone=$ZONE


echo "----------------------------------------------------------------------"
echo "      Retrieve the external address range of the source instance"
echo "----------------------------------------------------------------------"

gcloud compute instances describe source-instance --zone=$ZONE | grep natIP
EXTERNAL_IP=$(gcloud compute instances describe source-instance \
    --zone=$ZONE \
    --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

gcloud container clusters update private-cluster2 \
    --enable-master-authorized-networks \
    --zone=$ZONE \
    --master-authorized-networks $EXTERNAL_IP/32

echo "Job is Done!"