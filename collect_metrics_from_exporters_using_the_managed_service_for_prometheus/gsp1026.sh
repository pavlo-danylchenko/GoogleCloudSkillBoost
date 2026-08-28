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

echo "======================================================================"
echo "                    Task 1. Deploy GKE cluster"
echo "======================================================================"
gcloud container clusters create gmp-cluster \
    --num-nodes=1 \
    --zone=$ZONE \
    --enable-managed-prometheus

gcloud container clusters get-credentials gmp-cluster \
    --zone=$ZONE


echo "======================================================================"
echo "                    Task 2. Set up a namespace"
echo "======================================================================"
kubectl create ns gmp-test


echo "======================================================================"
echo "                 Task 3. Deploy the example application"
echo "======================================================================"
kubectl -n gmp-test apply \
    -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml


echo "======================================================================"
echo "              Task 4. Configure a PodMonitoring resource"
echo "======================================================================"
kubectl -n gmp-test apply \
    -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/pod-monitoring.yaml


echo "======================================================================"
echo "                Task 5. Download the prometheus binary"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/prometheus && cd prometheus
git checkout v2.28.1-gmp.4
wget https://storage.googleapis.com/kochasoft/gsp1026/prometheus
chmod a+x prometheus


echo "======================================================================"
echo "                 Task 6. Run the prometheus binary"
echo "======================================================================"
./prometheus \
  --config.file=documentation/examples/prometheus.yml \
  --export.label.project-id=$DEVSHELL_PROJECT_ID \
  --export.label.location=$ZONE \
  > /tmp/prometheus.log 2>&1 &

PROMETHEUS_DIR=$(pwd)
PROMETHEUS_PID=$!
echo "Prometheus started with PID $PROMETHEUS_PID"


echo "======================================================================"
echo "              Task 7. Download and run the node exporter"
echo "======================================================================"
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz
cd node_exporter-1.3.1.linux-amd64
NODE_EXPORTER_DIR=$(pwd)
./node_exporter \
    > /tmp/node_exporter.log 2>&1 &


echo "----------------------------------------------------------------------"
echo "                     Create a config.yaml file"
echo "----------------------------------------------------------------------"
kill "$PROMETHEUS_PID"
wait "$PROMETHEUS_PID" 2>/dev/null || true

cat > config.yaml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['localhost:9100']
EOF

gcloud storage buckets create -p $DEVSHELL_PROJECT_ID gs://$DEVSHELL_PROJECT_ID
gcloud storage cp config.yaml gs://$DEVSHELL_PROJECT_ID
gsutil -m acl set -R -a public-read gs://$DEVSHELL_PROJECT_ID

cd "$PROMETHEUS_DIR"
./prometheus \
    --config.file=config.yaml \
    --export.label.project-id=$DEVSHELL_PROJECT_ID \
    --export.label.location=$ZONE


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"