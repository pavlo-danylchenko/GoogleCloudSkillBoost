#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

read -p "Enter the Custom Security Role Name: " CSR_NAME
read -p "Enter the Service Account NAME: " SA_NAME
read -p "Enter the Cluster Name: " CLUSTER_NAME


export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "              Task 1. Create a custom security role"
echo "======================================================================"
cat > role-definition.yaml << EOF_END
title: "$CSR_NAME"
description: "Permissions"
stage: "ALPHA"
includedPermissions:
- storage.buckets.get
- storage.objects.get
- storage.objects.list
- storage.objects.update
- storage.objects.create
EOF_END

gcloud iam roles create $CSR_NAME --project $DEVSHELL_PROJECT_ID --file role-definition.yaml


echo "======================================================================"
echo "              Task 2. Create a service account"
echo "======================================================================"
gcloud iam service-accounts create $SA_NAME --display-name "Orca Private Cluster Service Account"



echo "======================================================================"
echo "       Task 3. Bind a custom security role to a service account"
echo "======================================================================"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA_NAME@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/monitoring.viewer

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA_NAME@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/monitoring.metricWriter

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA_NAME@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/logging.logWriter

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$SA_NAME@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --role projects/$DEVSHELL_PROJECT_ID/roles/$CSR_NAME


echo "======================================================================"
echo " Task 4. Create and configure a new Kubernetes Engine private cluster"
echo "======================================================================"
gcloud container clusters create $CLUSTER_NAME \
    --num-nodes=1 \
    --master-ipv4-cidr=172.16.0.64/28 \
    --network=orca-build-vpc \
    --subnetwork=orca-build-subnet \
    --enable-master-authorized-networks  \
    --master-authorized-networks 192.168.10.2/32 \
    --enable-ip-alias \
    --enable-private-nodes \
    --enable-private-endpoint \
    --service-account $SA_NAME@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com \
    --zone $ZONE


sleep 15

echo "======================================================================"
echo " Task 5. Deploy an application to a private Kubernetes Engine cluster"
echo "======================================================================"
gcloud compute ssh orca-jumphost \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet \
    --command="gcloud config set compute/zone $ZONE && gcloud container clusters get-credentials $CLUSTER_NAME --internal-ip && sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin && kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0 && kubectl expose deployment hello-server --name orca-hello-service --type LoadBalancer --port 80 --target-port 8080"

echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"