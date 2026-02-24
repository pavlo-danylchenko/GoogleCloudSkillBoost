# gcloud auth list
# export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
# export PROJECT_ID=$(gcloud config get-value project)
# gcloud config set compute/zone $ZONE
# gcloud config set compute/region $REGION

# gcloud compute networks list

# gcloud compute networks create workspace-vpc --subnet-mode=custom
# gcloud compute networks create private-vpc --subnet-mode=custom

gcloud compute networks peerings create workspace-to-private \
    --network=workspace-vpc \
    --peer-network=private-vpc

gcloud compute networks peerings create private-to-workspace \
    --network=private-vpc \
    --peer-network=workspace-vpc

