export REGION_1=us-east1
export REGION_2=asia-southeast1

# List the firewall rules
# gcloud compute firewall-rules list --filter="network=default"

gcloud compute firewall-rules list --filter="network=default" --format="value(name)" | xargs -r -I {} gcloud compute firewall-rules delete {} --quiet

gcloud compute networks delete default --quiet
gcloud compute networks create custom-vpc --subnet-mode=custom --bgp-routing-mode=regional

# Create Subnet in Region 1
gcloud compute networks subnets create subnet-1 \
    --network=custom-vpc \
    --range=10.0.1.0/24 \
    --region=$REGION_1

# Create Subnet in Region 2
gcloud compute networks subnets create subnet-2 \
    --network=custom-vpc \
    --range=10.0.2.0/24 \
    --region=$REGION_2

# gcloud compute firewall-rules create custom-vpc-allow-ssh-icmp \
#     --network=custom-vpc \
#     --allow=tcp:22,icmp \
#     --source-ranges=0.0.0.0/0



# List the VPC networks
# gcloud compute networks list

# List the subnets for your new VPC
# gcloud compute networks subnets list --network=custom-vpc
