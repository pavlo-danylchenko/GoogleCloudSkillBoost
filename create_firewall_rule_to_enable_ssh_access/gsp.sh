export VM_NAME=$(gcloud compute instances list --format="value(name)")
export ZONE=$(gcloud compute instances list --format="value(zone)")
export VPC_NAME=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="value(networkInterfaces[0].network.basename())")

gcloud compute firewall-rules create allow-ssh-ingress \
    --network=$VPC_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0