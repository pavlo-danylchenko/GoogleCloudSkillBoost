#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo "$ZONE - for vpc-demo-instance2"

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

# gcloud config set compute/zone $ZONE
# gcloud config set compute/region $REGION

read -p "Input ZONE #1 name: " ZONE_1
export REGION_1=$(echo $ZONE_1 | cut -d '-' -f 1-2)

read -p "Input ZONE #2 name: " ZONE_2
export REGION_2=$(echo $ZONE_2 | cut -d '-' -f 1-2)

echo "======================================================================"
echo "                     Task 1. Cloud VPC setup"
echo "======================================================================"
gcloud compute networks create vpc-demo --subnet-mode=custom


echo "----------------------------------------------------------------------"
echo "                          Create subnets"
echo "----------------------------------------------------------------------"
gcloud compute networks subnets create vpc-demo-subnet1 \
    --network=vpc-demo \
    --range=10.1.1.0/24 \
    --region=$REGION_1

gcloud compute networks subnets create vpc-demo-subnet2 \
    --network=vpc-demo \
    --range=10.2.1.0/24 \
    --region=$REGION_2


echo "----------------------------------------------------------------------"
echo "                        Create firewall rules"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create vpc-demo-allow-internal \
    --network=vpc-demo \
    --acction=ALLOW \
    --rules=icmp,tcp:0-65535,udp:0-65535 \
    --source-ranges=10.0.0.0/8


gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp \
    --network=vpc-demo \
    --action=ALLOW \
    --rules=icmp,tcp:22


echo "----------------------------------------------------------------------"
echo "                 Create vm instances in network vpc-demo"
echo "----------------------------------------------------------------------"
gcloud compute instances create vpc-demo-instance1 \
    --zone=$ZONE_2 \
    --subnet=vpc-demo-subnet1 \
    --machine-type=e2-medium


gcloud compute instances create vpc-demo-instance2 \
    --zone=$ZONE \
    --subnet=vpc-demo-subnet2 \
    --machine-type=e2-madium


echo "======================================================================"
echo "                  Task 2. Simulate on-premises setup"
echo "======================================================================"
gcloud compute networks create on-prem --subnet-mode=custom

gcloud compute networks subnets create on-prem-subnet1 \
    --network=on-prem \
    --range=192.168.1.0/24 \
    --region=$REGION_1


echo "----------------------------------------------------------------------"
echo "                        Create firewall rules"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create on-prem-allow-internal \
    --network=on-prem \
    --action=ALLOW \
    --rules=icmp,tcp:0-65535,udp0-65535 \
    --source-ranges=192.168.0.0/16

gcloud compute firewall-rules create on-prem-allow-ssh-icmp \
    --network=on-prem \
    --action=ALLOW \
    --rules=icmp,rdp,tcp:22


echo "----------------------------------------------------------------------"
echo "             Create a test instance in network on-prem"
echo "----------------------------------------------------------------------"
gcloud compute instances create on-prem-instance1 \
    --zone=$ZONE_1 \
    --subnet=on-prem-subnet1 \
    --machine-type=e2-medium


echo "======================================================================"
echo "                      Task 3. HA-VPN setup"
echo "======================================================================"
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 \
    --network=vpc-demo \
    --region=$REGION_1

gcloud compute vpn-gateways create on-prem-vpn-gw1 \
    --network=on-prem \
    --region=$REGION_1


echo "----------------------------------------------------------------------"
echo "                        Create cloud routers"
echo "----------------------------------------------------------------------"
gcloud compute routers create vpc-demo-router1 \
    --network=vpc-demo \
    --region=$REGION_1 \
    --asn=65001

gcloud compute routers create on-prem-router1 \
    --network=on-prem \
    --region=$REGION_1 \
    --asn=65002

echo "----------------------------------------------------------------------"
echo "                        Create two VPN tunnels"
echo "----------------------------------------------------------------------"
gcloud compute vpn-tunnels create vpc-demo-tunnel0 \
    --peer-gcp-gateway=on-prem-vpn-gw1 \
    --region=$REGION_1 \
    --ike-version=2 \
    --shared-secret=[SHARED_SECRET] \
    --router=vpc-demo-router1 \
    --vpn-gateway=vpc-demo-vpn-gw1 \
    --interface=0

gcloud compute vpn-tunnels create vpc-demo-tunnel1 \
    --peer-gcp-gateway=on-prem-vpn-gw1 \
    --region=$REGION_1 \
    --ike-version=2 \
    --shared-secret=[SHARED_SECRET] \
    --router=vpc-demo-router1 \
    --vpn-gateway=vpc-demo-vpn-gw1 \
    --interface=1


gcloud compute vpn-tunnels create on-prem-tunnel0 \
    --peer-gcp-gateway=vpc-demo-vpn-gw1 \
    --region=$REGION_1 \
    --ike-version=2 \
    --shared-secret=[SHARED_SECRET] \
    --router=on-prem-router1 \
    --vpn-gateway=on-prem-vpn-gw1 \
    --interface=0

gcloud compute vpn-tunnels create on-prem-tunnel1 \
    --peer-gcp-gateway=vpc-demo-vpn-gw1 \
    --region=$REGION_1 \
    --ike-version=2 \
    --shared-secret=[SHARED_SECRET] \
    --router=on-prem-router1 \
    --vpn-gateway=on-prem-vpn-gw1 \
    --interface=1


echo "----------------------------------------------------------------------"
echo "                    Create bgp peering for each tunnel"
echo "----------------------------------------------------------------------"

gcloud compute routers add-interface vpc-demo-router1 \
    --interface-name=if-tunnel0-to-on-prem \
    --ip-address=169.254.0.1 \
    --mask-length=30 \
    --vpn-tunnel=vpc-demo-tunnel0 \
    --region=$REGION_1


gcloud compute routers add-bgp-peer vpc-demo-router1 \
    --peer-name=bgp-on-prem-tunnel0 \
    --interface=if-tunnel0-to-on-prem \
    --peer-ip-address=169.254.0.2 \
    --peer-asn=65002 \
    --region=$REGION_1


gcloud compute routers add-interface vpc-demo-router1 \
    --interface-name=if-tunnel1-to-on-prem \
    --ip-address=169.254.1.1 \
    --mask-length=30 \
    --vpn-tunnel=vpc-demo-tunnel1 \
    --region=$REGION_1

gcloud compute routers add-bgp-peer vpc-demo-router1 \
    --peer-name=bgp-on-prem-tunnel1 \
    --interface=if-tunnel1-to-on-prem \
    --peer-ip-address=169.254.1.2 \
    --peer-asn=65002 \
    --region=$REGION_1


gcloud compute routers add-interface on-prem-router1 \
    --interface-name=if-tunnel0-to-vpc-demo \
    --ip-address=169.254.0.2 \
    --mask-length=30 \
    --vpn-tunnel=on-prem-tunnel0 \
    --region=$REGION_1


gcloud compute routers add-bgp-peer on-prem-router1 \
    --peer-name=bgp-vpc-demo-tunnel0 \
    --interface=if-tunnel0-to-vpc-demo \
    --peer-ip-address=169.254.0.1 \
    --peer-asn=65001 \
    --region=$REGION_1


gcloud compute routers add-interface on-prem-router1 \
    --interface-name=if-tunnel1-to-vpc-demo \
    --ip-address=169.254.1.2 \
    --mask-length=30 \
    --vpn-tunnel=on-prem-tunnel1 \
    --region=$REGION_1


gcloud compute routers add-bgp-peer on-prem-router1 \
    --peer-name=bgp-vpc-demo-tunnel1 \
    --interface=if-tunnel1-to-vpc-demo \
    --peer-ip-address=169.254.1.1 \
    --peer-asn=65001 \
    --region=$REGION_1


echo "----------------------------------------------------------------------"
echo "     Configure Firewall rules to allow traffic from the remote VPC"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create vpc-demo-allow-subnets-from-on-prem \
    --network=vpc-demo \
    --action=ALLOW \
    --rules=icmp,tcp,udp \
    --source-ranges=192.168.1.0/24

gcloud compute firewall-rules create on-prem-allow-subnets-from-vpc-demo \
    --network=on-prem \
    --action=ALLOW \
    --rules=icmp,tcp,udp \
    --source-ranges=10.1.1.0/24,10.2.1.0/24


echo "----------------------------------------------------------------------"
echo "                   Global routing with VPN"
echo "----------------------------------------------------------------------"
gcloud compute networks update vpc-demo \
    --bgp-routing-mode=GLOBAL


echo "----------------------------------------------------------------------"
echo "              Verify high availability of tunnels (OPTIONAL)"
echo "----------------------------------------------------------------------"
# gcloud compute vpn-tunnels delete vpc-demo-tunnel0  --region=$REGION_1


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"