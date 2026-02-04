#!/bin/bash
set -euo pipefail


export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-defaut-region])")
gcloud config set compute/region $REGION

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-defaut-zone])")
gcloud config set compute/zone $ZONE

echo "======================================================================"
echo "                        Task 1. Create a new instance"
echo "======================================================================"
gcloud compute instances create gcelab --zone $ZONE --machine-type=e2-standard-2


echo "======================================================================"
echo "                     Task 2. Create a new persistent disk"
echo "======================================================================"
gcloud compute disks create mydisk --size=200GB --zone $ZONE


echo "======================================================================"
echo "                     Task 3. Attaching a disk"
echo "======================================================================"
gcloud compute instances attach-disk gcelab --disk=mydisk --zone $ZONE


echo "----------------------------------------------------------------------"
echo "          Finding the persistent disk in the virtual machine"
echo "----------------------------------------------------------------------"
gcloud compute ssh gcelab --zone $ZONE --quiet \
    --command="ls -l /dev/disk/by-id \
    sudo mkdir /mnt/mydisk \
    sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 \
    && sudo mount -o discard,defaults /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 /mnt/mydisk"

echo "Job is Done!"