#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
read -p "Enter custom_metric: " custom_metric
read -p "Enter VALUE: " VALUE

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                   Task 1. Configure Cloud Monitoring"
echo "======================================================================"
gcloud services enable monitoring.googleapis.com --project=$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "Task 2. Configure a Compute Instance to generate Custom Cloud Monitoring metrics"
echo "======================================================================"
export INSTANCE_ID=$(gcloud compute instances describe video-queue-monitor \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE --format="get(id)")
echo "Stopping video-queue-monitor instance..."
gcloud compute instances stop video-queue-monitor --project=$DEVSHELL_PROJECT_ID --zone=$ZONE


echo "Creating startup script..."
cat > startup-script.sh << EOF
#!/bin/bash

echo "ZONE: $ZONE"
echo "REGION: $REGION"
echo "DEVSHELL_PROJECT_ID: $DEVSHELL_PROJECT_ID"

sudo apt update && sudo apt -y
sudo apt-get install wget -y
sudo apt-get -y install git
sudo chmod 777 /usr/local/
sudo wget https://go.dev/dl/go1.22.8.linux-amd64.tar.gz 
sudo tar -C /usr/local -xzf go1.22.8.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo service google-cloud-ops-agent start

mkdir -p /work/go/cache
export GOPATH=/work/go
export GOCACHE=/work/go/cache

cd /work/go
mkdir -p video
gsutil cp gs://spls/gsp338/video_queue/main.go /work/go/video/main.go

go get go.opencensus.io
go get contrib.go.opencensus.io/exporter/stackdriver

# Set project metadata
export MY_PROJECT_ID=$DEVSHELL_PROJECT_ID
export MY_GCE_INSTANCE_ID=$INSTANCE_ID
export MY_GCE_INSTANCE_ZONE=$ZONE

cd /work
go mod init go/video/main
go mod tidy
go run /work/go/video/main.go
EOF


echo "Applying startup script and starting instance..."
gcloud compute instances add-metadata video-queue-monitor \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --metadata-from-file startup-script=startup-script.sh

gcloud compute instances start video-queue-monitor \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE


echo "======================================================================"
echo " Task 3. Create a custom metric using Cloud Operations logging events"
echo "======================================================================"
echo "Creating logging metric for high resolution videos..."
gcloud logging metrics create $custom_metric \
    --description="Metric for high resolution video uploads" \
    --log-filter='textPayload=("file_format=4K" OR "file_format=8K")'


echo "Creating email notification channel..."
cat > email-channel.json << EOF
{
  "type": "email",
  "displayName": "VideoAlerts",
  "description": "Video Queue Monitoring",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create --channel-content-from-file="email-channel.json"


echo "======================================================================"
echo "Task 4. Add custom metrics to the Media Dashboard in Cloud Operations Monitoring"
echo "======================================================================"


echo "======================================================================"
echo "Task 5. Create a Cloud Operations alert based on the rate of high resolution video file uploads"
echo "======================================================================"

echo "Creating alert policy..."
channel_info=$(gcloud beta monitoring channels list)
channel_id=$(echo "$channel_info" | grep -oP 'name: \K[^ ]+' | head -n 1)

cat > video-queue-alert.json << EOF
{
  "displayName": "VideoAlert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "High Resolution Video Upload Rate",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"logging.googleapis.com/user/$custom_metric\"",
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
        "thresholdValue": $VALUE
      }
    }
  ],
  "alertStrategy": {
    "notificationPrompts": [
      "OPENED"
    ]
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$channel_id"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF

gcloud monitoring policies create --policy-from-file=video-queue-alert.json