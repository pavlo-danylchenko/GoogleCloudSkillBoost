#!/bin/bash
set -euo pipefail

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
