#!/bin/bash
set -euo pipefail

export PROJECT_ID=$(gcloud config get-value project)
export VM_NAME=$(gcloud compute instances list --limit=1 --format="value(name)")
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export DISK_NAME="encrypted-disk"

echo "----------------------------------------------------------------------"
echo "                      Generate the 256-bit key"
echo "----------------------------------------------------------------------"
openssl rand -base64 32 | tr -d '\n' > csek.key
export KEY_VALUE=$(cat csek.key)

echo "----------------------------------------------------------------------"
echo "                   Create the key-value map JSON file"
echo "----------------------------------------------------------------------"
cat > csek-map.json <<EOF
[
  {
    "uri": "https://www.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/disks/${DISK_NAME}",
    "key": "${KEY_VALUE}",
    "key-type": "raw"
  }
]
EOF

echo "----------------------------------------------------------------------"
echo "                   Create the encrypted disk"
echo "----------------------------------------------------------------------"
gcloud compute disks create $DISK_NAME \
    --size=200GB \
    --zone=$ZONE \
    --csek-key-file=csek-map.json

echo "----------------------------------------------------------------------"
echo "                   Assign disk to the VM Instance"
echo "----------------------------------------------------------------------"
gcloud compute instances attach-disk $VM_NAME \
    --disk=$DISK_NAME \
    --zone=$ZONE \
    --csek-key-file=csek-map.json

echo "JOB is DONE !"