#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                     Task 0. Set region/zone/environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                 Task 1. Perform infrastructure setup"
echo "======================================================================"
# gcloud services enable cloudaicompanion.googleapis.com
# gcloud container clusters list


echo "======================================================================"
echo "                   Task 2. Deploy an application"
echo "======================================================================"
git clone https://github.com/xiangshen-dk/microservices-demo.git
cd microservices-demo

gcloud container clusters get-credentials central --zone $ZONE
kubectl apply -f release/kubernetes-manifests.yaml

sleep 5

# kubectl get nodes

# export EXTERNAL_IP=$(kubectl get service frontend-external | awk 'BEGIN { cnt=0; } { cnt+=1; if (cnt > 1) print $4; }')
# curl -o /dev/null -s -w "%{http_code}\n"  http://$EXTERNAL_IP


echo "======================================================================"
echo "                 Task 4. Create a logs-based metric"
echo "======================================================================"
gcloud logging metrics create Error_Rate_SLI \
  --description="Error rate for recommendationservice" \
  --log-filter="resource.type=\"k8s_container\" severity=ERROR labels.\"k8s-pod/app\": \"recommendationservice\""

sleep 5

cat > policy-config.json << EOF
{
  "displayName": "Error Rate SLI",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Container - logging/user/Error_Rate_SLI",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_container\" AND metric.type = \"logging.googleapis.com/user/Error_Rate_SLI\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0.5
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF

gcloud monitoring policies create --policy-from-file="policy-config.json"


echo "======================================================================"
echo "                       JOB is DONE !!!"
echo "======================================================================"