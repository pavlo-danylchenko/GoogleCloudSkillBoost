#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                    Task 1. Configuring your environment"
echo "======================================================================"

echo "GET ZONE bofore setting up"
gcloud config get-value compute/zone
echo "Next steps"

export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")
gcloud config set compute/region $REGION
gcloud config get-value compute/region

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
gcloud config set compute/zone $ZONE
gcloud config get-value compute/zone

export PROJECT_ID=$(gcloud config get-value project)
gcloud config get-value project
gcloud compute project-info describe --project=$PROJECT_ID

echo -e "PROJECT_ID: $PROJECT_ID\nZONE: $ZONE"


echo "----------------------------------------------------------------------"
echo "             Creating a virtual machine with the gcloud tool"
echo "----------------------------------------------------------------------"
gcloud compute instances create gcelab2 --zone=$ZONE --machine-type=e2-medium

echo "----------------------------------------------------------------------"
echo "                     Exploring gcloud commands"
echo "----------------------------------------------------------------------"
gcloud config list
gcloud config list --all
gcloud components list

echo "======================================================================"
echo "                    Task 2. Filtering command-line output"
echo "======================================================================"
gcloud compute instances list

echo "----------------------------------------------------------------------"
echo "                    List the gcelab2 virtual machine"
echo "----------------------------------------------------------------------"
gcloud compute instances list --filter="name=('gcelab2')"

gcloud compute firewall-rules list

echo "----------------------------------------------------------------------"
echo "             List the firewall rules for the default network"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules list --filter="network='default'"

echo "----------------------------------------------------------------------"
echo "List the firewall rules for the default network where the allow rule matches an ICMP rule"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules list --filter="NETWORK='default' AND ALLOW='icmp'"


# echo "======================================================================"
# echo "                   Task 3. Connecting to your VM instance"
# echo "======================================================================"
# gcloud compute ssh gcelab2 --zone=$ZONE --quiet \
#     --command="sudo apt-get update && sudo apt-get install -y nginx \
#     exit"


echo "======================================================================"
echo "                     Task 4. Updating the firewall"
echo "======================================================================"
gcloud compute firewall-rules list
gcloud compute instances add-tags gcelab2 --zone=$ZONE \
    --tags=http-server,https-server
gcloud compute firewall-rules create default-allow-http \
    --network=default --direction=INGRESS --priority=1000 \
    --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

echo "----------------------------------------------------------------------"
echo "             List the firewall rules for the project"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules list --filter=ALLOW:'80'

echo "----------------------------------------------------------------------"
echo "   Verify communication is possible for http to the virtual machine"
echo "----------------------------------------------------------------------"
# curl http://$(gcloud compute instances list --filter="name=gcelab2" \
#     --format="value(EXTERNAL_IP)")


echo "======================================================================"
echo "                     Task 5. Viewing the system logs"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "             View the available logs on the system"
echo "----------------------------------------------------------------------"
gcloud logging logs list

echo "----------------------------------------------------------------------"
echo "             View the logs that relate to compute resources"
echo "----------------------------------------------------------------------"
gcloud logging logs list -filter="compute"

echo "----------------------------------------------------------------------"
echo "       Read the logs related to the resource type of gce_instance"
echo "----------------------------------------------------------------------"
gcloud logging read "resource.type=gce_instance" --limit 5

echo "----------------------------------------------------------------------"
echo "             Read the logs for a specific virtual machine"
echo "----------------------------------------------------------------------"
gcloud logging read "resource.type=gce_instance AND labels.instance_name=gcelab2" \
    --limit 5

echo "The JOB is DONE!"