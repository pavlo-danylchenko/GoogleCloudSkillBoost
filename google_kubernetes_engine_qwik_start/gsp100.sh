#!/bin/bash

# Task 1. Set a default compute zone
gcloud config set compute/zone $ZONE

# Task 2. Create a GKE cluster
gcloud container clusters create --machine-type=e2-medium --zone=$ZONE lab-cluster

# Task 3. Get authentication credentials for the cluster
gcloud container clusters get-credentials lab-cluster

# Task 4. Deploy an application to the cluster
kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment hello-server --type=LoadBalancer --port 8080

# Task 5. Delete the cluster
sleep 70
gcloud container clusters delete lab-cluster

echo "Job is Done!"