#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                        Getting list of projects"
echo "----------------------------------------------------------------------"
# PROJECTS=($(gcloud projects list --format="value(projectId)" --limit=2))
# PROJECT_A=${PROJECTS[0]}
# PROJECT_B=${PROJECTS[1]}

PROJECT_A=$GOOGLE_CLOUD_PROJECT
PROJECT_B=$(gcloud projects list --format="value(projectId)" --filter="projectId != $PROJECT_A" --limit=1)
echo "Project A ID: $PROJECT_A"
echo "Project B ID: $PROJECT_B"
PROJECTS=("$PROJECT_A" "$PROJECT_B")


# echo "----------------------------------------------------------------------"
# echo "                        Getting REGIONS and ZONES"
# echo "----------------------------------------------------------------------"
# echo "Project A"
# export REGION_A=$(gcloud compute project-info describe --project=$PROJECT_A \
#     --format="value(commonInstanceMetadata.items[google-compute-default-region])")
# export ZONE_A=$(gcloud compute project-info describe --project=$PROJECT_A \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# echo "Project B"
# export REGION_B=$(gcloud compute project-info describe --project=$PROJECT_B \
#     --format="value(commonInstanceMetadata.items[google-compute-default-region])")
# export ZONE_B=$(gcloud compute project-info describe --project=$PROJECT_B \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# echo "Project A ($PROJECT_A): $REGION_A / $ZONE_A"
# echo "Project B ($PROJECT_B): $REGION_B / $ZONE_B"

echo "======================================================================"
echo "            Task 1. Create a custom network in both projects"
echo "======================================================================"

for PROJ in "${PROJECTS[@]}"; do
    echo "----------------------------------------------------------------------"
    echo "                  Getting REGION and ZONE for $PROJ"
    echo "----------------------------------------------------------------------"

    REGION=$(gcloud compute project-info describe --project=$PROJ \
        --format="value(commonInstanceMetadata.items[google-compute-default-region])")
    ZONE=$(gcloud compute project-info describe --project=$PROJ \
        --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
    
    REGION=${REGION:-us-central1}
    ZONE=${ZONE:-us-central1-a}

    if [ "$PROJ" == "$PROJECT_A" ]; then
        NET="network-a"; SUBNET="network-a-subnet"; RANGE="10.0.0.0/16";
        VM="vm-a"; FW="network-a-fw";
        export REGION_A=$REGION;
        export ZONE_A=$ZONE;
    else
        NET="network-b"; SUBNET="network-b-subnet"; RANGE="10.8.0.0/16";
        VM="vm-b"; FW="network-b-fw";
        export REGION_B=$REGION;
        export ZONE_B=$ZONE;
    fi
    
    echo "----------------------------------------------------------------------"
    echo "       Create a custom network in project $PROJ, region $REGION"
    echo "----------------------------------------------------------------------"
    gcloud compute networks create $NET --subnet-mode custom \
        --project $PROJ
    
    echo "----------------------------------------------------------------------"
    echo "     Create a subnet within VPC and specify a region and IP range"
    echo "----------------------------------------------------------------------"
    gcloud compute networks subnets create $SUBNET \
        --network $NET --range $RANGE --region $REGION --project $PROJ
    
    echo "----------------------------------------------------------------------"
    echo "                        Create a VM instance"
    echo "----------------------------------------------------------------------"
    gcloud compute instances create $VM --zone $ZONE --project $PROJ \
        --network $NET --subnet $SUBNET --machine-type e2-small 
    
    echo "----------------------------------------------------------------------"
    echo "                        Enable SSH and icmp"
    echo "----------------------------------------------------------------------"
    gcloud compute firewall-rules create $FW --project $PROJ \
        --network $NET --allow tcp:22,icmp 
done

echo ">>> Task #1 Completed <<<"


echo "======================================================================"
echo "             Task 2. Set up a VPC network peering session"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                     Peer network-A with network-B"
echo "----------------------------------------------------------------------"
gcloud compute networks peerings create peer-ab --project $PROJECT_A \
    --network network-a --peer-project $PROJECT_B --peer-network network-b

echo "----------------------------------------------------------------------"
echo "                     Peer network-B with network-A"
echo "----------------------------------------------------------------------"
gcloud compute networks peerings create peer-ba --project $PROJECT_B \
    --network network-b --peer-project $PROJECT_A --peer-network network-a


echo "======================================================================"
echo "                 Task 3. Test connectivity (OPTIONAL)"
echo "======================================================================"
# INTERNAL_IP_A=$(gcloud compute instances describe vm-a \
#     --project=$PROJECT_A \
#     --zone=$ZONE_A \
#     --format='get(networkInterfaces[0].networkIP)')

# echo "Internal IP vm-a: $INTERNAL_IP_A"

# gcloud compute ssh vm-b --project=$PROJECT_B --zone=$ZONE_B --quiet \
#     --tunnel-through-iap \
#     --command="ping -c 3 $INTERNAL_IP_A"

echo "Job is Done!"