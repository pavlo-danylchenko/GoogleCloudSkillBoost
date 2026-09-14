#!/bin/bash
set -euo pipefail

# Monitor Environments with Google Cloud Managed Service for Prometheus: Challenge Lab

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                  Task 1. Deploy a GKE cluster in ZONE"
echo "======================================================================"
gcloud container clusters create gmp-cluster \
    --zone=$ZONE \
    --num-node=1 \
    --enable-managed-prometheus

gcloud container clusters get-credentials gmp-cluster \
    --zone=$ZONE

kubectl create ns gmp-test

echo "======================================================================"
echo "                 Task 2. Deploy a managed collection"
echo "======================================================================"
kubectl -n gmp-test apply \
    -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/manifests/setup.yaml

kubectl -n gmp-test apply \
    -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/manifests/operator.yaml


echo "======================================================================"
echo "                 Task 3. Deploy an example application"
echo "======================================================================"
kubectl -n gmp-test apply \
    -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml


echo "======================================================================"
echo "                 Task 4. Filter exported metrics"
echo "======================================================================"
# cat > op-config.yaml << EOF
# apiVersion: monitoring.googleapis.com/v1alpha1
# collection:
#   filter:
#     matchOneOf:
#     - '{job="prom-example"}'
#     - '{__name__=~"job:.+"}'
# kind: OperatorConfig
# metadata:
#   annotations:
#     components.gke.io/layer: addon
#     kubectl.kubernetes.io/last-applied-configuration: |
#       {"apiVersion":"monitoring.googleapis.com/v1alpha1","kind":"OperatorConfig","metadata":{"annotations":{"components.gke.io/layer":"addon"},"labels":{"addonmanager.kubernetes.io/mode":"Reconcile"},"name":"config","namespace":"gmp-public"}}
#   creationTimestamp: "2022-03-14T22:34:23Z"
#   generation: 1
#   labels:
#     addonmanager.kubernetes.io/mode: Reconcile
#   name: config
#   namespace: gmp-public
#   resourceVersion: "2882"
#   uid: 4ad23359-efeb-42bb-b689-045bd704f295
# EOF

# gcloud storage buckets create -p $DEVSHELL_PROJECT_ID gs://$DEVSHELL_PROJECT_ID
# gcloud storage cp op-config.yaml gs://$DEVSHELL_PROJECT_ID
# gsutil -m acl set -R -a public-read gs://$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"