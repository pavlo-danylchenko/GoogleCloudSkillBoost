#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
# export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
# gcloud config set run/region $REGION


echo "======================================================================"
echo "               Task 1. Create a Compute Engine instance"
echo "======================================================================"
gcloud compute instances create lamp-1-vm \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --machine-type=e2-medium \
    --subnet default \
    --image-family debian-12 \
    --image-project debian-cloud \
    --tags=http-server

gcloud compute firewall-rules create default-allow-http \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

sleep 10

echo "======================================================================"
echo "           Task 2. Add Apache2 HTTP Server to your instance"
echo "======================================================================"
cat > setup.sh << EOF
sudo apt-get update
sudo apt-get install -y apache2 php7.0
sudo service apache2 restart
EOF

gcloud compute ssh lamp-1-vm \
    --zone=$ZONE \
    --tunnel-through-iap \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./setup.sh

export EXTERNAL_IP=$(gcloud compute instances describe lamp-1-vm --zone=$ZONE \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

curl -I http://$EXTERNAL_IP


echo "----------------------------------------------------------------------"
echo "               Create a Monitoring Metrics Scope"
echo "----------------------------------------------------------------------"
gcloud services enable monitoring.googleapis.com

echo "----------------------------------------------------------------------"
echo "               Install the Monitoring and Logging agents"
echo "----------------------------------------------------------------------"
cat > setup_02.sh << EOF
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo systemctl status google-cloud-ops-agent"*"
sudo apt-get update
EOF

gcloud compute ssh lamp-1-vm \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./setup_02.sh

echo "======================================================================"
echo "                     Task 3. Create an uptime check"
echo "======================================================================"
# INSTANCE_CP=$(gcloud compute instances describe lamp-1-vm --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --format='json' | jq -r '.id')

EXTERNAL_IP=$(gcloud compute instances describe lamp-1-vm \
    --zone="$ZONE" \
    --project="$DEVSHELL_PROJECT_ID" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

echo "$EXTERNAL_IP"

gcloud monitoring uptime create "Lamp Uptime Check" \
    --resource-type=uptime-url \
    --resource-labels="host=$EXTERNAL_IP,project_id=$DEVSHELL_PROJECT_ID" \
    --protocol=http \
    --path="/" \
    --port=80 \
    --period=1 \
    --project="$DEVSHELL_PROJECT_ID"


echo "======================================================================"
echo "                   Task 4. Create an alerting policy"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "           Step 4.1: Create the Email Notification Channel"
echo "----------------------------------------------------------------------"
gcloud beta monitoring channels create \
    --display-name="My Alert Channel" \
    --type=email \
    --channel-labels=email_address="danilchenko@ukr.net" \
    --description="Primary email for lab alerts"


echo "----------------------------------------------------------------------"
echo "                 Step 4.2: Get the Channel ID"
echo "----------------------------------------------------------------------"
export CHANNEL_ID=$(gcloud beta monitoring channels list \
    --filter='display_name="My Alert Channel"' \
    --format='value(name)')


echo "----------------------------------------------------------------------"
echo "                Step 4.3: Create the Alerting Policy"
echo "----------------------------------------------------------------------"
cat > policy-config.json << EOF
{
  "displayName": "Inbound Traffic Alert",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Traffic Threshold Condition",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/interface/traffic\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 500,
        "duration": "60s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ],
  "notificationChannels": [
    "$CHANNEL_ID"
  ],
  "documentation": {
    "content": "The network traffic on lamp-1-vm has exceeded 500. Please investigate.",
    "mimeType": "text/markdown"
  }
}
EOF

gcloud alpha monitoring policies create --policy-from-file="policy-config.json"


echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"