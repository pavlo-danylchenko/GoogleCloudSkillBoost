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

echo "======================================================================"
echo "                 Task 3. Testing in your own environment"
echo "======================================================================"
gcloud compute firewall-rules create iperf-testing \
    --allow tcp:5001,udp:5001 \
    --direction ingress \
    --network default \
    --source-ranges 0.0.0.0/0