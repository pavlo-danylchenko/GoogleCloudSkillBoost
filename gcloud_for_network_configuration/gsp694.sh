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
echo "                     Task 1. Viewing networks"
echo "======================================================================"
gcloud compute networks list
gcloud compute networks describe labnet
gcloud compute networks describe privatenet


echo "======================================================================"
echo "                     Task 2. List subnets"
echo "======================================================================"
gcloud compute networks subnets list


echo "======================================================================"
echo "                     Task 3. Describe a subnet"
echo "======================================================================"
gcloud compute networks subnets describe labnet-sub \
    --region=$REGION


echo "======================================================================"
echo "                     Task 4. Creating firewall rules"
echo "======================================================================"
gcloud compute firewall-rules create labnet-allow-internal \
	--network=labnet \
	--action=ALLOW \
	--rules=icmp,tcp:22 \
	--source-ranges=0.0.0.0/0

echo "======================================================================"
echo "                   Task 5. Viewing firewall rules details"
echo "======================================================================"
gcloud compute firewall-rules describe labnet-allow-internal


echo "======================================================================"
echo "         Task 6. Create another firewall rule for privatenet"
echo "======================================================================"
gcloud compute firewall-rules create privatenet-deny \
    --network=privatenet \
    --action=DENY \
    --rules=icmp,tcp:22 \
    --source-ranges=0.0.0.0/0

echo "======================================================================"
echo "                     Task 7. List VM instances"
echo "======================================================================"
gcloud compute instances list


echo "======================================================================"
echo "                   Task 8. Explore the connectivity"
echo "======================================================================"
