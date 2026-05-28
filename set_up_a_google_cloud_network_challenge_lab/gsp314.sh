#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"


read -p "Enter the NETWORK_NAME: " NETWORK_NAME
read -p "Enter the SUBNET_A_NAME: " SUBNET_A_NAME
read -p "Enter the SUBNET_B_NAME: " SUBNET_B_NAME
read -p "Enter the ZONE #1: " ZONE_1
read -p "Enter the ZONE #2: " ZONE_2
read -p "Enter the FIREWALL_RULE_NAME #1: " FIREWALL_RULE_NAME_1
read -p "Enter the FIREWALL_RULE_NAME #2: " FIREWALL_RULE_NAME_2
read -p "Enter the FIREWALL_RULE_NAME #3: " FIREWALL_RULE_NAME_3

export REGION_1=$(echo $ZONE_1 | cut -d '-' -f 1-2)
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)
# export REGION_3=$(echo $ZONE_3 | cut -d '-' -f 1-2)

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                  Task 1. Create networks"
echo "======================================================================"
gcloud compute networks create $NETWORK_NAME \
    --subnet-mode=custom

gcloud compute networks subnets create $SUBNET_A_NAME \
    --network=$NETWORK_NAME \
    --region=$REGION_1 \
    --range=10.10.10.0/24

gcloud compute networks subnets create $SUBNET_B_NAME \
    --network=$NETWORK_NAME \
    --region=$REGION_2 \
    --range=10.10.20.0/24


echo "======================================================================"
echo "                  Task 2. Add firewall rules"
echo "======================================================================"
gcloud compute firewall-rules create $FIREWALL_RULE_NAME_1 \
    --network=$NETWORK_NAME \
    --direction=INGRESS \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0

gcloud compute firewall-rules create $FIREWALL_RULE_NAME_2 \
    --network=$NETWORK_NAME \
    --priority=65535 \
    --direction=INGRESS \
    --allow=tcp:3389 \
    --source-ranges=0.0.0.0/24

gcloud compute firewall-rules create $FIREWALL_RULE_NAME_3 \
    --network=$NETWORK_NAME \
    --priority=1000 \
    --direction=INGRESS \
    --allow=icmp \
    --source-ranges=10.10.10.0/24,10.10.20.0/24


echo "======================================================================"
echo "                    Task 3. Add VMs to your network"
echo "======================================================================"
gcloud compute instances create us-test-01 \
    --zone=$ZONE_1 \
    --subnet=$SUBNET_A_NAME \
    --machine-type=e2-standard-2


gcloud compute instances create us-test-02 \
    --zone=$ZONE_2 \
    --subnet=$SUBNET_B_NAME \
    --machine-type=e2-standard-2

echo "======================================================================"
echo "                         JOB is DONE !"
echo "======================================================================"