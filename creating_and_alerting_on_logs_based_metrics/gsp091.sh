#!/bin/bash
set -euo pipefail

echo "Task 1. Deploy a GKE cluster"
# export PROJECT_ID=$(gcloud info --format='value(config.project)')

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone $ZONE

echo "Deploy a standard GKE cluster"
gcloud container clusters create gmp-cluster --num-nodes=1 --zone=$ZONE

echo "======================================================================"
echo "                  Task 2. Create a log-based alert"
echo "======================================================================"
gcloud beta monitoring channels create \
    --type=email \
    --channel-label=email_address=danilchenko@ukr.net \
    --display-name="Email Channel" \
    --description="Channel for VM alerts"

export CHANNEL_ID=$(gcloud beta monitoring channels list \
    --type=email \
    --filter='displayName="Email Channel"' \
    --format='value(name)' 
)
cat > email-channel.json << EOF
{
  "displayName": "stopped vm",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Log match condition: VM Stopped",
      "conditionMatchedLog": {
        "filter": "resource.type=\"gce_instance\" protoPayload.methodName=\"v1.compute.instances.stop\""
      }
    }
  ],
  "alertStrategy": {
    "notificationRateLimit": {
      "period": "300s"
    },
    "autoClose": "3600s"
  },
  "notificationChannels": [
    "$CHANNEL_ID"
  ],
  "enabled": true
}
EOF

# sed "s|CHANNEL_ID|$CHANNEL_ID|" email-channel.json > final-email-channel.json

gcloud monitoring policies create --policy-from-file="email-channel.json"



gcloud logging metrics create stopped-vm \
    --description="Metric for stopped VMs" \
    --log-filter='resource.type="gce_instance" protoPayload.methodName="v1.compute.instances.stop"'

echo "Task 3. Create a Docker repository"
gcloud artifacts repositories create doker-repo --repository-format=docker \
    --location=$REGION --description="Docker repository" \
    --project=$DEVSHELL_PROJECT_ID

echo "In Cloud Shell load a pre-built image from a storage bucket"
wget https://storage.googleapis.com/spls/gsp1024/flask_telemetry.zip
unzip flask_telemetry.zip
docker load -i flask_telemetry.tar

docker tag gcr.io/ops-demo-330920/flask_telemetry:61a2a7aabc7077ef474eb24f4b69faeab47deed9 \
$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1

docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1

echo "======================================================================"
echo "       Task 4. Deploy a simple application that emits metrics"
echo "======================================================================"
gcloud container clusters get-credentials gmp-cluster
kubectl create ns gmp-test
echo "Get the application which emits metrics at the /metrics endpoint"
wget https://storage.googleapis.com/spls/gsp1024/gmp_prom_setup.zip
unzip gmp_prom_setup.zip
cd gmp_prom_setup

sed -i "s|<ARTIFACT REGISTRY IMAGE NAME>|$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1|g" flask_deployment.yaml
kubectl -n gmp-test apply -f flask_deployment.yaml
kubectl -n gmp-test apply -f flask_service.yaml

echo "======================================================================"
echo "                  Task 5. Create a log-based metric"
echo "======================================================================"
gcloud logging metrics create hello-app-error \
    --description="Metric for Hello App Errors" \
    --log-filter='severity=ERROR
resource.labels.container_name="hello-app"
textPayload: "ERROR: 404 Error page not found"'


echo "======================================================================"
echo "                  Task 6. Create a metrics-based alert"
echo "======================================================================"

cat > log-metric-alert.json << EOF
{
  "displayName": "log based metric alert",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Log-based metric condition",
      "conditionThreshold": {
        "filter": "metric.type = \"logging.googleapis.com/user/hello-app-error\" AND resource.type = \"gce_instance\"",
        "aggregations": [
          {
            "alignmentPeriod": "120s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.001,
        "duration": "0s",
        "trigger": {
          "count": 1
        }
      }
    }
  ],
  "enabled": true,
  "notificationChannels": ["$CHANNEL_ID"]
}
EOF

gcloud monitoring policies create --policy-from-file="log-metric-alert.json"

echo "======================================================================"
echo "                  Task 7. Generate some errors"
echo "======================================================================"
timeout 120 bash -c -- 'while true; do curl $(kubectl get services -n gmp-test -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')/error; sleep $((RANDOM % 4)) ; done'

echo "Job is Done!"