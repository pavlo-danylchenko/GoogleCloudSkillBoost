#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo " Task 1. Viewing Cloud Run function logs & metrics in Cloud Monitoring"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# gcloud services enable \
#     run.googleapis.com \
#     cloudbuild.googleapis.com \
#     artifactregistry.googleapis.com

# mkdir helloworld && cd helloworld

#  UI
# cat > index.js << EOF
# const functions = require('@google-cloud/functions-framework');

# functions.http('helloHttp', (req, res) => {
#   res.set('Content-Type', 'text/plain');
#   res.send(`Hello ${req.query.name || req.body.name || 'World'}!`);
# });
# EOF

# cat > package.json << EOF
# {
#   "dependencies": {
#     "@google-cloud/functions-framework": "^3.0.0"
#   }
# }
# EOF

# gcloud run deploy helloworld \
#     --source=. \
#     --region=$REGION \
#     --allow-unauthenticated \
#     --execution-environment=gen2 \
#     --max-instances=5

# gcloud functions deploy $CSF_NAME \
#   --gen2 \
#   --runtime nodejs24 \
#   --entry-point $CSF_NAME \
#   --source . \
#   --region $REGION \
#   --trigger-bucket $DEVSHELL_PROJECT_ID \
#   --trigger-location $REGION \
#   --max-instances 2 \
#   --quiet

curl -LO 'https://github.com/tsenart/vegeta/releases/download/v12.12.0/vegeta_12.12.0_linux_386.tar.gz'
tar -xvzf vegeta_12.12.0_linux_386.tar.gz

# CLOUD_RUN_URL=$(gcloud run services describe helloworld \
#     --region=$REGION \
#     --format='value(status.url)')

# echo "GET $CLOUDRUN_URL" | ./vegeta attack -duration=300s -rate=200 > results.bin

echo "======================================================================"
echo "                  Task 2. Create a logs-based metric"
echo "======================================================================"
gcloud logging metrics create CloudRunFunctionLatency-Logs \
    --project=$DEVSHELL_PROJECT_ID \
    --description="Latency of Cloud Run Function" \
    --log-filter='resource.type="cloud_run_revision" resource.labels.service_name="helloworld"'


echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"