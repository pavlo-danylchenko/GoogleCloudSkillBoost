#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)


echo "======================================================================"
echo "        Task 1. Set the default region and zone for all resources"
echo "======================================================================"
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "             Task 2. Create multiple web server instances"
echo "======================================================================"
gcloud compute instances create www1 \
    --zone=$ZONE \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www1</h3>" | tee /var/www/html/index.html'


gcloud compute instances create www2 \
    --zone=$ZONE \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www2</h3>" | tee /var/www/html/index.html'


gcloud compute instances create www3 \
    --zone=$ZONE \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www3</h3>" | tee /var/www/html/index.html'

gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags=network-lb-tag --allow tcp:80

sleep 5

gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
IP_ADDRESSES=($(gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)"))

for IP in "${IP_ADDRESSES[@]}"
do
    if [ -n "$IP" ]; then
        echo "Checking the instance ..."
        curl -s "http://$IP"
        echo "--------------------------"
    else
        echo "There is no EXTRENAL IP Address!!!"
    fi
done


echo "======================================================================"
echo "            Task 3. Configure the load balancing service"
echo "======================================================================"
gcloud compute addresses create network-lb-ip-1 \
  --region $REGION

gcloud compute http-health-checks create basic-check


echo "======================================================================"
echo "          Task 4. Create the target pool and forwarding rule"
echo "======================================================================"
gcloud compute target-pools create www-pool \
    --region $REGION --http-health-check basic-check

gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3

gcloud compute forwarding-rules create www-rule \
    --region $REGION \
    --ports 8080 \
    --address network-lb-ip-1 \
    --target-pool www-pool


echo "======================================================================"
echo "                 Task 5. Send traffic to your instances"
echo "======================================================================"
IP_ADDRESS=$(gcloud compute forwarding-rules describe www-rule --region $REGION --format="json" | jq -r .IPAddress)
echo $IPADDRESS


while true; do curl -m1 $IPADDRESS; done

echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"