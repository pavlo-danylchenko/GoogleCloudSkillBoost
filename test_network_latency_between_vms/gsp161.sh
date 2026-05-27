#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"


read -p "Enter the ZONE #1: " ZONE_1
read -p "Enter the ZONE #2: " ZONE_2
read -p "Enter the ZONE #3: " ZONE_3

export REGION_1=$(echo $ZONE_1 | cut -d '-' -f 1-2)
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)
export REGION_3=$(echo $ZONE_3 | cut -d '-' -f 1-2)

export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")


export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "          Task 1. Connect VMs and check latency"
echo "======================================================================"
gcloud compute instances create us-test-01 \
    --zone=$ZONE_1 \
    --subnet=subnet-$REGION_1 \
    --machine-type=e2-standard-2 \
    --tags=ssh,http,rules

gcloud compute instances create us-test-02 \
    --zone=$ZONE_2 \
    --subnet=subnet-$REGION_2 \
    --machine-type=e2-standard-2 \
    --tags=ssh,http,rules

gcloud compute instances create us-test-03 \
    --zone=$ZONE_3 \
    --subnet=subnet-$REGION_3 \
    --machine-type=e2-standard-2 \
    --tags=ssh,http,rules

gcloud compute instances create us-test-04 \
    --subnet=subnet-$REGION_1 \
    --zone=$ZONE_1 \
    --machine-type=e2-standard-2 \
    --tags=ssh,http


echo "======================================================================"
echo "               Task 2. Traceroute and Performance testing"
echo "======================================================================"
cat > start.sh << 'EOF'
#!/bin/bash

sudo apt-get update
sudo apt-get -y install traceroute mtr tcpdump iperf whois host dnsutils siege
traceroute www.icann.org
EOF

gcloud compute ssh us-test-01 \
    --zone=$ZONE_1 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh


gcloud compute ssh us-test-02 \
    --zone=$ZONE_2 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh


echo "======================================================================"
echo "                 Task 3. Use iperf to test performance"
echo "======================================================================"
cat > iperf_server.sh << EOF
nohup iperf -s > iperf-server.log 2>&1 &
EOF

cat > iperf_client_01.sh << EOF
iperf -c us-test-01.$ZONE_1 #run in client mode
EOF

cat > iperf_client_02.sh << EOF
iperf -c us-test-02.$ZONE_2 -u -b 2G #iperf client side - send 2 Gbits/s
EOF

cat > setup.sh << EOF
sudo apt-get update
sudo apt-get -y install traceroute mtr tcpdump iperf whois host dnsutils siege
EOF

gcloud compute ssh us-test-01 \
    --zone=$ZONE_1 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./iperf_server.sh


gcloud compute ssh us-test-02 \
    --zone=$ZONE_2 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./iperf_client_01.sh


gcloud compute ssh us-test-04 \
    --zone=$ZONE_1 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./setup.sh


gcloud compute ssh us-test-02 \
    --zone=$ZONE_2 \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./iperf_server.sh


echo "======================================================================"
echo "                         JOB is DONE!"
echo "=====================================================================