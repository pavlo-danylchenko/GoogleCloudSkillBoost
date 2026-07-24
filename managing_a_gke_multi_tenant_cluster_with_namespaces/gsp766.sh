#!/bin/bash
# set -euo pipefail

echo "======================================================================"
echo "                     Task 0. Set region/zone/ENV"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $REGION
echo $ZONE

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                 Task 1. Download required files"
echo "======================================================================"
gsutil -m cp -r gs://spls/gsp766/gke-qwiklab ~
cd ~/gke-qwiklab


echo "======================================================================"
echo "                 Task 2. View and create namespaces"
echo "======================================================================"
gcloud container clusters get-credentials multi-tenant-cluster

echo "----------------------------------------------------------------------"
echo "                     Creating new namespaces"
echo "----------------------------------------------------------------------"
kubectl create namespace team-a
kubectl create namespace team-b

kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity && \
kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-b -- sleep infinity

kubectl get pods -A

kubectl describe pod app-server -n team-a

kubectl config set-context --current -n team-a

kubectl describe pod app-server

echo "======================================================================"
echo "                 Task 3. Access Control in namespaces"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                           IAM Roles"
echo "----------------------------------------------------------------------"

gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
    --member=serviceAccount:team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com  \
    --role=roles/container.clusterViewer

echo "----------------------------------------------------------------------"
echo "                         Kubernetes RBAC"
echo "----------------------------------------------------------------------"
kubectl create -f developer-role.yaml

kubectl create rolebinding team-a-developers \
    --role=developer --user=team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com


echo "----------------------------------------------------------------------"
echo "                        Test the rolebinding"
echo "----------------------------------------------------------------------"
gcloud iam service-accounts keys create /tmp/key.json \
    --iam-account team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

# gcloud auth activate-service-account  --key-file=/tmp/key.json

# gcloud container clusters get-credentials multi-tenant-cluster --zone ${ZONE} --project ${GOOGLE_CLOUD_PROJECT}


echo "======================================================================"
echo "                        Task 4. Resource quotas"
echo "======================================================================"
kubectl create quota test-quota \
    --hard=count/pods=2,count/services.loadbalancers=1 --namespace=team-a

kubectl run app-server-2 --image=quay.io/centos/centos:9 -n team-a -- sleep infinity

kubectl describe quota test-quota --namespace=team-a

# export KUBE_EDITOR="nano"
# kubectl edit quota test-quota --namespace=team-a

kubectl get quota test-quota --namespace=team-a -o yaml | \
  sed 's/count\/pods: "2"/count\/pods: "6"/' | \
  kubectl apply -f -

kubectl describe quota test-quota --namespace=team-a

echo "----------------------------------------------------------------------"
echo "                       CPU and memory quotas"
echo "----------------------------------------------------------------------"
kubectl create -f cpu-mem-quota.yaml
kubectl create -f cpu-mem-demo-pod.yaml --namespace=team-a
kubectl describe quota cpu-mem-quota --namespace=team-a

echo "======================================================================"
echo "              Task 5. Monitoring GKE and GKE usage metering"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                         GKE usage metering"
echo "----------------------------------------------------------------------"
gcloud container clusters \
  update multi-tenant-cluster --zone ${ZONE} \
  --resource-usage-bigquery-dataset cluster_dataset


echo "----------------------------------------------------------------------"
echo "                Create the GKE cost breakdown table"
echo "----------------------------------------------------------------------"
export GCP_BILLING_EXPORT_TABLE_FULL_PATH=${GOOGLE_CLOUD_PROJECT}.billing_dataset.gcp_billing_export_v1_xxxx
export USAGE_METERING_DATASET_ID=cluster_dataset
export COST_BREAKDOWN_TABLE_ID=usage_metering_cost_breakdown
export USAGE_METERING_QUERY_TEMPLATE=~/gke-qwiklab/usage_metering_query_template.sql
export USAGE_METERING_QUERY=cost_breakdown_query.sql
export USAGE_METERING_START_DATE=2020-10-26

sed \
    -e "s/\${fullGCPBillingExportTableID}/$GCP_BILLING_EXPORT_TABLE_FULL_PATH/" \
    -e "s/\${projectID}/$GOOGLE_CLOUD_PROJECT/" \
    -e "s/\${datasetID}/$USAGE_METERING_DATASET_ID/" \
    -e "s/\${startDate}/$USAGE_METERING_START_DATE/" \
    "$USAGE_METERING_QUERY_TEMPLATE" \
    > "$USAGE_METERING_QUERY"


bq query \
    --project_id=$GOOGLE_CLOUD_PROJECT \
    --use_legacy_sql=false \
    --destination_table=$USAGE_METERING_DATASET_ID.$COST_BREAKDOWN_TABLE_ID \
    --schedule='every 24 hours' \
    --display_name="GKE Usage Metering Cost Breakdown Scheduled Query" \
    --replace=true \
    "$(cat $USAGE_METERING_QUERY)"


echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"