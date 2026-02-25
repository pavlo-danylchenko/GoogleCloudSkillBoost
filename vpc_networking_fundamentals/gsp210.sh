#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE_1=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE_1
export REGION_1=$(echo $ZONE_1 | cut -d '-' -f 1-2)
echo $REGION_1

read -p "Enter the GCP ZONE #2: " ZONE_2
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)

# List and delete all firewall rules associated with the default network
gcloud compute firewall-rules delete $(gcloud compute firewall-rules list \
    --filter="network:default" --format="value(name)") --quiet

gcloud compute networks delete default --quiet

echo "======================================================================"
echo "              Task 2. Create a VPC network and VM instances"
echo "======================================================================"
#  Enough for completion
# gcloud compute networks create mynetwork --subnet-mode=auto

# gcloud compute instances create mynet-us-vm --machine-type=e2-micro --zone=$ZONE_1 --network-interface=subnet=mynetwork
# gcloud compute instances create mynet-second-vm --machine-type=e2-micro --zone=$ZONE_2 --network-interface=subnet=mynetwork

# Correct solution
gcloud compute networks create mynetwork --subnet-mode=auto --bgp-routing-mode=regional --bgp-best-path-selection-mode=legacy
gcloud compute firewall-rules create mynetwork-allow-custom --network=mynetwork \
 --direction=INGRESS --priority=65534 --source-ranges=10.128.0.0/9 --action=ALLOW --rules=all
gcloud compute firewall-rules create mynetwork-allow-icmp --network=mynetwork --direction=INGRESS --priority=65534 --source-ranges=0.0.0.0/0 --action=ALLOW --rules=icmp
gcloud compute firewall-rules create mynetwork-allow-rdp --network=mynetwork --direction=INGRESS --priority=65534 --source-ranges=0.0.0.0/0 --action=ALLOW --rules=tcp:3389
gcloud compute firewall-rules create mynetwork-allow-ssh --network=mynetwork --direction=INGRESS --priority=65534 --source-ranges=0.0.0.0/0 --action=ALLOW --rules=tcp:22

gcloud compute instances create mynet-us-vm --machine-type=e2-micro --zone=$ZONE_1 --network-interface=subnet=mymynetworknw
gcloud compute instances create mynet-second-vm --machine-type=e2-micro --zone=$ZONE_2 --network-interface=subnet=mynetwork

