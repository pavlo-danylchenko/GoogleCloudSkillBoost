#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                        Set ZONE_2 manually"
echo "======================================================================"

read -p "Enter the ZONE_2 " ZONE_2
if [[ -z "$ZONE_2" ]]; then
  echo "ZONE_2 cannot be empty. Please provide a valid zone."]]
    exit 1
fi
echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "======================================================================"
export ZONE_1=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION_1=$(echo $ZONE_1 | cut -d '-' -f 1-2)
# export REGION_1=$(gcloud compute project-info describe \
#     --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)


echo "======================================================================"
echo "                   Task 1. Configuring instances"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "    Create the four instances in region $REGION_1 and $REGION_2"
echo "----------------------------------------------------------------------"


gcloud compute instances create www-1 \
    --image-family debian-11 \
    --image-project debian-cloud \
    --machine-type e2-micro \
    --zone $ZONE_1 \
    --tags http-tag \
    --metadata startup-script="#! /bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      Code"

gcloud compute instances create www-2 \
    --image-family debian-11 \
    --image-project debian-cloud \
    --machine-type e2-micro \
    --zone $ZONE_1 \
    --tags http-tag \
    --metadata startup-script="#! /bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      Code"

gcloud compute instances create www-3 \
    --image-family debian-11 \
    --image-project debian-cloud \
    --machine-type e2-micro \
    --zone $ZONE_2 \
    --tags http-tag \
    --metadata startup-script="#! /bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      Code"


gcloud compute instances create www-4 \
    --image-family debian-11 \
    --image-project debian-cloud \
    --machine-type e2-micro \
    --zone $ZONE_2 \
    --tags http-tag \
    --metadata startup-script="#! /bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      Code"

echo "----------------------------------------------------------------------"
echo "                  Create firewall rule to allow HTTP traffic"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create www-firewall \
    --target-tags http-tag \
    --allow tcp:80


echo "======================================================================"
echo "             Task 2. Configuring services for load balancing"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "   Create IPv4 global static external IP address for load balancer"
echo "----------------------------------------------------------------------"
gcloud compute addresses create lb-ip-cr \
    --ip-version=IPV4 \
    --global

echo "----------------------------------------------------------------------"
echo "              Create an instance group for each zone"
echo "----------------------------------------------------------------------"
gcloud compute instance-groups unmanaged create $REGION_1-resources-w --zone $ZONE_1
gcloud compute instance-groups unmanaged create $REGION_2-resources-w --zone $ZONE_2

echo "----------------------------------------------------------------------"
echo "               Add the instances to the instance groups"
echo "----------------------------------------------------------------------"
gcloud compute instance-groups unmanaged add-instances $REGION_1-resources-w \
    --instances www-1,www-2 \
    --zone $ZONE_1

gcloud compute instance-groups unmanaged add-instances $REGION_2-resources-w \
    --instances www-3,www-4 \
    --zone $ZONE_2

echo "----------------------------------------------------------------------"
echo "                       Create a Health Check"
echo "----------------------------------------------------------------------"
gcloud compute health-checks create http http-basic-check


echo "======================================================================"
echo "             Task 3. Configuring the load balancing service"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "For each instance group, define an HTTP service and map a port name to the relevant port:"
echo "----------------------------------------------------------------------"
gcloud compute instance-groups unmanaged set-named-ports $REGION_1-resources-w \
    --named-ports http:80 \
    --zone $ZONE_1

gcloud compute instance-groups unmanaged set-named-ports $REGION_2-resources-w \
    --named-ports http:80 \
    --zone $ZONE_2

gcloud compute backend-services create web-map-backend-service \
    --protocol HTTP \
    --health-checks http-basic-check \
    --global

gcloud compute backend-services add-backend web-map-backend-service \
    --balancing-mode UTILIZATION \
    --max-utilization 0.8 \
    --capacity-scaler 1 \
    --instance-group $REGION_1-resources-w \
    --instance-group-zone $ZONE_1 \
    --global

gcloud compute backend-services add-backend web-map-backend-service \
    --balancing-mode UTILIZATION \
    --max-utilization 0.8 \
    --capacity-scaler 1 \
    --instance-group $REGION_2-resources-w \
    --instance-group-zone $ZONE_2 \
    --global

gcloud compute url-maps create web-map \
    --default-service web-map-backend-service

gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map

LB_IP_ADDRESS=$(gcloud compute addresses list --format="get(ADDRESS)")

gcloud compute forwarding-rules create http-cr-rule \
    --address $LB_IP_ADDRESS \
    --global \
    --target-http-proxy http-lb-proxy \
    --ports 80

echo "======================================================================"
echo "             Task 4. Sending traffic to your instances"
echo "======================================================================"

echo "======================================================================"
echo "Task 5. Shutting off HTTP access from everywhere but the load balancing service"
echo "======================================================================"

echo "======================================================================"
echo "  Task 6. (Optional) Removing external IPs except for a bastion host"
echo "======================================================================"


echo "Job is Done!"