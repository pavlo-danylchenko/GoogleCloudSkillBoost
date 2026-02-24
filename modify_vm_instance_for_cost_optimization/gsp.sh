export VM_NAME=lab-vm
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# 1. Stop the VM instance
gcloud compute instances stop $VM_NAME --zone=$ZONE

# 2. Update the machine type to e2-medium
gcloud compute instances set-machine-type $VM_NAME \
    --machine-type=e2-medium \
    --zone=$ZONE

# 3. Start the VM instance again
gcloud compute instances start $VM_NAME --zone=$ZONE

# 4. Verify the machine type
gcloud compute instances describe $VM_NAME --zone=$ZONE --format="get(machineType)"