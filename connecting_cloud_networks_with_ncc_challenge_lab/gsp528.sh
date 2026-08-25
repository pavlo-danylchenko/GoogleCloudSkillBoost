#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $REGION
echo $ZONE

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
# gcloud services enable networkconnectivity.googleapis.com


echo "======================================================================"
echo "                Task 1. Connect 2 On-prem VPCs with NCC"
echo "======================================================================"
gcloud network-connectivity hubs create ncc-hub

OFFICE1_TUNNELS=$(gcloud compute vpn-tunnels list \
    --filter="name~'^onprem-office1-to-routing-tunnel-'" \
    --format="value(name)" | paste -sd, -)

OFFICE2_TUNNELS=$(gcloud compute vpn-tunnels list \
    --filter="name~'^onprem-office2-to-routing-tunnel-'" \
    --format="value(name)" | paste -sd, -)

gcloud network-connectivity spokes linked-vpn-tunnels create office-1-spoke \
    --hub=ncc-hub \
    --vpn-tunnels="$OFFICE1_TUNNELS" \
    --region=$REGION \
    --project=$DEVSHELL_PROJECT_ID

gcloud network-connectivity spokes linked-vpn-tunnels create office-2-spoke \
    --hub=ncc-hub \
    --vpn-tunnels="$OFFICE2_TUNNELS" \
    --region=$REGION \
    --project=$DEVSHELL_PROJECT_ID

echo "======================================================================"
echo "                    Task 2. Connect VPC to VPC"
echo "======================================================================"
gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke \
    --hub=ncc-hub \
    --vpc-network=workload-vpc-1 \
    --global \
    --project=$DEVSHELL_PROJECT_ID

gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke \
    --hub=ncc-hub \
    --vpc-network=workload-vpc-2 \
    --global \
    --project=$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "                   Task 3. Connect VPC to On-prem"
echo "======================================================================"
gcloud network-connectivity spokes linked-vpc-network create hybrid-office-1-spoke \
    --hub=ncc-hub \
    --vpc-network=on-prem-office-1-vpc \
    --global \
    --project=$DEVSHELL_PROJECT_ID

# gcloud compute ssh workload1-vm \
#     --zone=$ZONE \
#     --tunnel-through-iap \
#     --project=$DEVSHELL_PROJECT_ID \
#     --command="ping -c 4 10.1.0.2"

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"