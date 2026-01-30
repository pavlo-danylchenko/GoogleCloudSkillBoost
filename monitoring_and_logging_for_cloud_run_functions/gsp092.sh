#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo " Task 1. Viewing Cloud Run function logs & metrics in Cloud Monitoring"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# gcloud services enable \
#     run.googleapis.com \
#     cloudbuild.googleapis.com \
#     artifactregistry.googleapis.com

mkdir helloworld && cd helloworld

echo "Create an index.js file"
cat > index.js << EOF
const functions = require('@google-cloud/functions-framework');

functions.http('helloWorld', (req, res) => {
  res.send('Hello, World!');
});
EOF


# const functions = require('@google-cloud/functions-framework');

# functions.http('helloHttp', (req, res) => {
#   res.set('Content-Type', 'text/plain');
#   res.send(`Hello ${req.query.name || req.body.name || 'World'}!`);
# });

# {
#   "dependencies": {
#     "@google-cloud/functions-framework": "^3.0.0"
#   }
# }


echo "Create a package.json file"
cat > package.json << EOF
{
  "name": "helloworld",
  "version": "1.0.0",
  "engines": {
    "node": "22"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

gcloud run deploy helloworld \
    --source=. \
    --region=$REGION \
    --allow-unauthenticated \
    --execution-environment=gen2 \
    --max-instances=5

curl -LO 'https://github.com/tsenart/vegeta/releases/download/v12.12.0/vegeta_12.12.0_linux_386.tar.gz'
tar -xvzf vegeta_12.12.0_linux_386.tar.gz

# CLOUD_RUN_URL=$(gcloud run services describe helloworld \
#     --region=$REGION \
#     --format='value(status.url)')

# echo "GET $CLOUDRUN_URL" | ./vegeta attack -duration=300s -rate=200 > results.bin

echo "Task 2. Create a logs-based metric"
echo "======================================================================"
echo "                  Task 2. Create a logs-based metric"
echo "======================================================================"
gcloud logging metrics create CloudRunFunctionLatency-Logs \
    --project=$DEVSHELL_PROJECT_ID \
    --description="Latency of Cloud Run Function" \
    --log-filter='resource.type="cloud_run_revision" resource.labels.service_name="helloworld"'

echo "Job is Done!"