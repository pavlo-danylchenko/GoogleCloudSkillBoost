#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                 Task 1. Create the cloud VPC"
echo "======================================================================"
gcloud compute networks create cloud --subnet-mode custom

gcloud compute firewall-rules create cloud-fw --network cloud \
    --allow tcp:22,tcp:5001,udp:5001,icmp

read -p "Input ZONE #2 name: " ZONE_2
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)

gcloud compute networks subnets create cloud-east --network cloud \
    --range 10.0.1.0/24 --region $REGION_2


echo "======================================================================"
echo "                 Task 2. Create the on-prem VPC"
echo "======================================================================"
gcloud compute networks create on-prem --subnet-mode custom

gcloud compute firewall-rules create on-prem-fw --network on-prem \
    --allow tcp:22,tcp:5001,udp:5001,icmp

gcloud compute networks subnets create on-prem-central --network on-prem \
    --range 192.168.1.0/24 --region $REGION


echo "======================================================================"
echo "                     Task 3. Create VPN gateways"
echo "======================================================================"
gcloud compute networks target-vpn-gateways create cloud-gw1 --network cloud \
    --region $REGION_2

gcloud compute networks target-vpn-gateways create on-prem-gw1 --network on-prem \
    --region $REGION


echo "======================================================================"
echo "Task 4. Create a route-based VPN tunnel between local and Google Cloud networks"
echo "======================================================================"
gcloud compute addresses create cloud-gw1 --region $REGION_2
gcloud compute addresses create on-prem-gw1 --region $REGION

cloud_gw1_ip=$(gcloud compute addresses describe cloud-gw1 \
                    --region $REGION_2 --format="value(address)")

on_prem_gw_ip=$(gcloud compute addresses describe on-prem-gw1 \
                    --region $REGION --format="value(address)")

gcloud compute forwarding-rules create cloud-1-fr-esp --ip-protocol ESP \
    --address $cloud_gw1_ip --target-vpn-gateway cloud-gw1 --region $REGION_2

gcloud compute forwarding-rules create cloud-1-fr-udp500 --ip-protocol UDP \
    --ports 500 --address $cloud_gw1_ip --target-vpn-gateway cloud-gw1 --region $REGION_2

gcloud compute forwarding-rules create cloud-1-fr-udp4500 --ip-protocol UDP \
    --ports 4500 --address $cloud_gw1_ip --target-vpn-gateway cloud-gw1 --region $REGION_2

gcloud compute forwarding-rules create on-prem-fr-esp --ip-protocol ESP \
    --address $on_prem_gw_ip --target-vpn-gateway on-prem-gw1 --region $REGION

gcloud compute forwarding-rules create on-prem-fr-udp500 --ip-protocol UDP \
    --ports 500 --address $on_prem_gw_ip --target-vpn-gateway on-prem-gw1 --region $REGION

gcloud compute forwarding-rules create on-prem-fr-udp4500 --ip-protocol UDP \
    --ports 4500 --address $on_prem_gw_ip --target-vpn-gateway on-prem-gw1 --region $REGION

gcloud compute vpn-tunnels create on-prem-tunnel1 --peer-address $cloud_gw1_ip \
    --target-vpn-gateway on-prem-gw1 --ike-version 2 --local-traffic-selector 0.0.0.0/0 \
    --remote-traffic-selector 0.0.0.0/0 --shared-secret=sharedsecret --region $REGION

gcloud compute vpn-tunnels create cloud-tunnel1 --peer-address $on_prem_gw_ip \
    --target-vpn-gateway cloud-gw1 -ike-version 2 --local-traffic-selector 0.0.0.0/0 \
    --remote-traffic-selector 0.0.0.0/0 --shared-secret=sharedsecret --region $REGION_2

gcloud compute routes create on-prem-route1 --destination-range 10.0.1.0/24 \
    --network on-prem --next-hop-vpn-tunnel on-prem-tunnel1 --next-hop-vpn-tunnel-region $REGION

gcloud compute routes create cloud-route1 --destination-range 192.168.1.0/24 \
    --network cloud --next-hop-vpn-tunnel cloud-tunnel1 --next-hop-vpn-tunnel-region $REGION_2


echo "======================================================================"
echo "                Task 5. Test throughput over VPN"
echo "======================================================================"
gcloud compute instances create cloud-loadtest \
    --zone=$ZONE_2 \
    --machine-type=e2-standard-4 \
    --subnet cloud-east \
    --image-family debian-11 \
    --image-project debian-cloud \
    --boot-disk-size 10 \
    --boot-disk-type pd-standard \
    --boot-disk-device-name cloud-loadtest

gcloud compute instances create on-prem-loadtest \
    --zone $ZONE \
    --machine-type=e2-standard-4 \
    --subnet on-prem-central \
    --image-family debian-11 \
    --image-project debian-cloud \
    --boot-disk-size 10 \
    --boot-disk-type pd-standard \
    --boot-disk-device-name on-prem-loadtest

gcloud compute ssh cloud-loadtest --zone=$ZONE_2 --quiet \
    --command="sudo apt-get install -y iperf && iperf -s -i 5 && iperf -c 192.168.1.2 -P 20 -x C && exit"


gcloud compute ssh on-prem-loadtest --zone=$ZONE --quiet \
    --command="sudo apt-get install -y iperf && iperf -s -i 5 && iperf -c 192.168.1.2 -P 20 -x C && exit"

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"