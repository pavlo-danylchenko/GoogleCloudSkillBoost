#!/bin/bash
# set -euo pipefail
echo "======================================================================"
echo "               Task 1. Configure the gcloud environment"
echo "======================================================================"
gcloud --version
gcloud auth list --quiet

echo "----------------------------------------------------------------------"
echo "           Create a new instance and updating the default zone"
echo "----------------------------------------------------------------------"
export ZONE=$(gcloud compute project-info describe \
        --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

gcloud compute instances create lab-1 --zone=$ZONE \
        --machine-type=e2-standard-2

export NEW_ZONE=$(gcloud compute zones list \
    --filter="region:($REGION) AND name:!($ZONE)" \
    --format="value(name)" | shuf -n 1)
gcloud config set compute/zone $NEW_ZONE

wait_for_confirm() {
    local user_input=""
    # Continue looping as long as input is NOT 'y' or 'Y'
    while [[ "$user_input" != "y" && "$user_input" != "Y" ]]; do
        echo -e "\n[ACTION REQUIRED]: Have you confirmed the previous step in the GCP Console?"
        read -p "Enter 'Y' to continue (or 'N' to be reminded again): " user_input
        
        if [[ "$user_input" == "n" || "$user_input" == "N" ]]; then
            echo "Standing by... Please finish the task before proceeding."
        elif [[ "$user_input" != "y" && "$user_input" != "Y" ]]; then
            echo "Invalid input. Please enter Y or N."
        fi
    done
    echo "Confirmation received. Proceeding to next task..."
}

wait_for_confirm

echo "======================================================================"
echo "    Task 2. Create and switch between multiple IAM configurations"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                 Create a new IAM configuration"
echo "----------------------------------------------------------------------"
# 1. Create the new configuration named 'user2'
gcloud config configurations create user2 --quiet

# 2. Trigger the login flow specifically for this config
# This will provide the URL for you to click
gcloud auth login --no-launch-browser --quiet

# 3. Set the project ID for this configuration
gcloud config set project $(gcloud config get-value project --configuration=default) --configuration=user2
# 4. Optional: Set a default zone or region
gcloud config set compute/zone $(gcloud config get-value compute/zone --configuration=default) --configuration=user2
gcloud config set compute/region $(gcloud config get-value compute/region --configuration=default) --configuration=user2

gcloud config configurations activate default


echo "======================================================================"
echo "          Task 3. Identify and assign correct IAM permissions"
echo "======================================================================"
sudo yum -y install epel-release
sudo yum -y install jq

read -p "Enter PROJECT_ID_2: " PROJECT_ID_2
read -p "Enter USER_ID_2: " USER_ID_2
read -p "Enter ZONE_2: " ZONE_2

# export PROJECT_ID_2 USER_ID_2 ZONE_2
echo "export PROJECTID2=$PROJECT_ID_2" >> ~/.bashrc
echo "export USERID2=$USER_ID_2" >> ~/.bashrc
echo "export ZONE2=$ZONE_2" >> ~/.bashrc

. ~/.bashrc
gcloud projects add-iam-policy-binding $PROJECT_ID_2 --member user:$USER_ID_2 --role=roles/viewer

echo "======================================================================"
echo "                 Task 4. Test that user2 has access"
echo "======================================================================"
gcloud config configurations activate user2
gcloud config set project $PROJECT_ID_2
gcloud config configurations activate default

echo "----------------------------------------------------------------------"
echo "                   Create a new role with permissions"
echo "----------------------------------------------------------------------"
gcloud iam roles create devops --project $PROJECT_ID_2 --permissions "compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"

echo "----------------------------------------------------------------------"
echo "           Bind the role to the second account to both projects"
echo "----------------------------------------------------------------------"
gcloud projects add-iam-policy-binding $PROJECT_ID_2 --member user:$USER_ID_2 --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECT_ID_2 --member user:$USER_ID_2 --role=projects/$PROJECT_ID_2/roles/devops


echo "----------------------------------------------------------------------"
echo "               Test the newly assigned permissions"
echo "----------------------------------------------------------------------"
gcloud config configurations activate user2
gcloud compute instances create lab-2 --zone $ZONE_2 --machine-type=e2-standard-2

echo "======================================================================"
echo "                   Task 5. Using a service account"
echo "======================================================================"
gcloud config configurations activate default
gcloud config set project $PROJECT_ID_2
gcloud iam service-accounts create devops --display-name devops

export SA=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=devops")
gcloud projects add-iam-policy-binding $PROJECT_ID_2 --member serviceAccount:$SA --role=roles/iam.serviceAccountUser

echo "======================================================================"
echo "       Task 6. Using the service account with a compute instance"
echo "======================================================================"
gcloud projects add-iam-policy-binding $PROJECT_ID_2 --member serviceAccount:$SA --role=roles/compute.instanceAdmin
gcloud compute instances create lab-3 --zone $ZONE_2 --machine-type=e2-standard-2 --service-account $SA --scopes "https://www.googleapis.com/auth/compute"

echo "JOB is DONE!"