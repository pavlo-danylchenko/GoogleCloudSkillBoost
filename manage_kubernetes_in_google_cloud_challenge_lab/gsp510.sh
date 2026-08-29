#!/bin/bash
set -euo pipefail

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

# read -p "ENTER the CLUSTER NAME: " CLUSTER_NAME
# read -p "ENTER the NAMESPACE NAME: " NAMESPACE_NAME
# read -p "ENTER the REPO NAME: " REPO_NAME
# read -p "ENTER the SERVICE NAME: " SERVICE_NAME

echo "======================================================================"
echo "Do not forget to EXPORT other ENV VARIABLES from the LAB SETUP SECTION"
echo "======================================================================"

read -p "ENTER the INTERVAL: " INTERVAL

gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID

echo "======================================================================"
echo "                    Task 1. Create a GKE cluster"
echo "======================================================================"
sleep 20

gcloud container clusters create $CLUSTER_NAME\
    --release-channel=regular \
    --enable-autoscaling \
    --min-nodes=2 \
    --max-nodes=6 \
    --num-nodes 3 \
    --zone=$ZONE

gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE

echo "======================================================================"
echo "         Task 2. Enable Managed Prometheus on the GKE cluster"
echo "======================================================================"
gcloud container clusters update $CLUSTER_NAME \
    --enable-managed-prometheus

kubectl create ns $NAMESPACE_NAME

gcloud storage cp gs://spls/gsp510/prometheus-app.yaml .

sed -i \
    -e "s/- image: <todo>/- image: nilebox\/prometheus-example-app:latest/" \
    -e "s/- name: <todo>/- name: metrics/" \
    -e "s/name: <todo>/name: prometheus-test/" \
    prometheus-app.yaml

kubectl -n $NAMESPACE_NAME apply -f prometheus-app.yaml

gcloud storage cp gs://spls/gsp510/pod-monitoring.yaml .

sed -i \
    -e "s/name: <todo>/name: prometheus-test/" \
    -e "s/app.kubernetes.io\/name: <todo>/app.kubernetes.io\/name: prometheus-test/" \
    -e "s/app: <todo>/app: prometheus-test/" \
    -e "s/interval: <todo>/interval: ${INTERVAL}/" \
    pod-monitoring.yaml

kubectl -n $NAMESPACE_NAME apply -f pod-monitoring.yaml


echo "======================================================================"
echo "           Task 3. Deploy an application onto the GKE cluster"
echo "======================================================================"
gcloud storage cp -r gs://spls/gsp510/hello-app/ .
cd hello-app/manifests

kubectl -n $NAMESPACE_NAME apply -f helloweb-deployment.yaml


echo "======================================================================"
echo "         Task 4. Create a logs-based metric and alerting policy"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                     Create a logs-based metric"
echo "----------------------------------------------------------------------"
gcloud logging metrics create pod-image-errors \
  --description="pod-image-errors" \
  --log-filter='resource.type="k8s_pod" severity="WARNING"'

sleep 5

echo "----------------------------------------------------------------------"
echo "                     Create an alerting policy"
echo "----------------------------------------------------------------------"
cat > policy-config.json << EOF
{
  "displayName": "Pod Error Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Pod - logging/user/pod-image-errors",
      "conditionThreshold": {
        "filter": 'resource.type = "k8s_pod" AND metric.type = "logging.googleapis.com/user/pod-image-errors"',
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_COUNT"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": []
}
EOF

gcloud monitoring policies create --policy-from-file="policy-config.json"


echo "======================================================================"
echo "              Task 5. Update and re-deploy your app"
echo "======================================================================"
sed -i \
    -e "s/image: <todo>/image: us-docker.pkg.dev\/google-samples\/containers\/gke\/hello-app:1.0/" \
    helloweb-deployment.yaml

kubectl delete deployments helloweb -n $NAMESPACE_NAME
kubectl -n $NAMESPACE_NAME apply -f helloweb-deployment.yaml



echo "======================================================================"
echo "    Task 6. Containerize your code and deploy it onto the cluster"
echo "======================================================================"
cd ../
sed -i \
    -e "s/Version: 1.0.0/Version: 2.0.0/" \
    main.go

# LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE:TAG
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

docker build -t $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO_NAME/hello-app:v2 .
 
docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO_NAME/hello-app:v2
  
kubectl set image deployment/helloweb \
    -n $NAMESPACE_NAME \
    hello-app=$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO_NAME/hello-app:v2
  
kubectl expose deployment helloweb \
    -n $NAMESPACE_NAME \
    --name=$SERVICE_NAME \
    --type=LoadBalancer \
    --port 8080 \
    --target-port 8080

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"