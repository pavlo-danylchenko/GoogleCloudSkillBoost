#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

export PROJECT_ID=$(gcloud config get-value project)

gcloud compute firewall-rules list --filter=network:external-network


echo "======================================================================"
echo "                Task 1. Create a global firewall rule"
echo "======================================================================"
gcloud compute firewall-rules create allow-ssh \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=10.1.0.0/24,10.2.0.0/24 \
    --description="allow-ssh" \
    --network=external-network \
    --target-tags=ssh

gcloud compute firewall-rules create allow-web \
    --allow=tcp:80,tcp:443 \
    --description="allow-web" \
    --source-ranges=10.0.0.0/16 \
    --network=external-network \
    --target-tags=web


echo "======================================================================"
echo "             Task 2. Save details of existing network tags"
echo "======================================================================"
gcloud beta compute firewall-rules migrate \
    --source-network=external-network \
    --export-tag-mapping \
    --tag-mapping-file=firewall-rules.json


echo "======================================================================"
echo "                   Task 3. Create secure Tags"
echo "======================================================================"
export TAG_KEY=vpc-tags
export NETWORK_NAME=external-network
export TAG_MAPPING_FILE="tag-mapping.json"
export POLICY_NAME=firewall-policy

gcloud resource-manager tags keys create $TAG_KEY \
    --parent projects/$DEVSHELL_PROJECT_ID \
    --purpose GCE_FIREWALL \
    --purpose-data network=$DEVSHELL_PROJECT_ID/$NETWORK_NAME

export SSH_TAG=$(gcloud resource-manager tags values create ssh \
    --parent=$DEVSHELL_PROJECT_ID/$TAG_KEY \
    --format="value(name)")

export EXTERNAL_TAG=$(gcloud resource-manager tags values create external \
    --parent=$DEVSHELL_PROJECT_ID/$TAG_KEY \
    --format="value(name)")

export WEB_TAG=$(gcloud resource-manager tags values create web \
    --parent=$DEVSHELL_PROJECT_ID/$TAG_KEY \
    --format="value(name)")

echo "======================================================================"
echo "          Task 4. Map network tags and service accounts to Tags"
echo "======================================================================"
cat > $TAG_MAPPING_FILE << EOF
{
  "ssh": "$SSH_TAG",
  "web": "$WEB_TAG",
  "external": "$EXTERNAL_TAG"
}
EOF


echo "======================================================================"
echo "                      Task 5. Bind Tags to VMs"
echo "======================================================================"
gcloud beta compute firewall-rules migrate \
   --source-network=$NETWORK_NAME \
   --bind-tags-to-instances \
   --tag-mapping-file=$TAG_MAPPING_FILE


echo "======================================================================"
echo " Task 6. Migrate the VPC firewall rules to a global network firewall"
echo "======================================================================"
gcloud beta compute firewall-rules migrate \
    --source-network=$NETWORK_NAME \
    --tag-mapping-file=$TAG_MAPPING_FILE \
    --target-firewall-policy=$POLICY_NAME

echo "======================================================================"
echo "                      Task 7. Review VM tags"
echo "======================================================================"
# gcloud compute instances list --filter="tags.items:(ssh OR web OR external)" \
#     --format="table(name, tags.items)"

echo "======================================================================"
echo "Task 8. Associate the global network firewall policy with your network"
echo "======================================================================"
gcloud compute network-firewall-policies associations create \
  --firewall-policy=$POLICY_NAME \
  --network=$NETWORK_NAME \
  --global-firewall-policy

echo "======================================================================"
echo "        Task 9. Change the policy and rule evaluation order"
echo "======================================================================"
gcloud compute networks update $NETWORK_NAME \
    --network-firewall-policy-enforcement-order=BEFORE_CLASSIC_FIREWALL

gcloud compute networks get-effective-firewalls $NETWORK_NAME | grep "TYPE:"


echo "======================================================================"
echo "              Task 10. Enable logging of firewall rules"
echo "======================================================================"
gcloud compute network-firewall-policies rules update 1000 \
    --firewall-policy=$POLICY_NAME \
    --enable-logging \
    --global-firewall-policy


echo "======================================================================"
echo "            Task 11. Test the global network firewall policy"
echo "======================================================================"
export EXTERNAL_IP=$(gcloud compute instances list \
  --filter="name:external-server" \
  --format="value(EXTERNAL_IP)")

export INTERNAL_IP=$(gcloud compute instances list \
  --filter="name:internal-server-1" \
  --format="value(INTERNAL_IP)")

ping -c 5 $EXTERNAL_IP

echo "Manual Step Required: Connectivity Test (Task 11)"

echo "Open Connectivity Test:"
echo "https://console.cloud.google.com/net-intelligence/connectivity/tests"

echo ""
echo "Create Test 1 (External → Internal):"
echo "Source IP: $EXTERNAL_IP"
echo "Type: External IP"
echo "Destination IP: $INTERNAL_IP"
echo "Port: 80"

echo ""
echo "Create Test 2 (Internal → External):"
echo "Source IP: $INTERNAL_IP"
echo "Type: Internal IP"
echo "Source network: internal-network"
echo "Destination IP: $EXTERNAL_IP"

echo ""

read -p "Press Enter after completing Task 11..."
read -p "Press Enter after completing Task 11... (double check)"


echo "======================================================================"
echo "       Task 12. Delete the VPC firewall rules from the network"
echo "======================================================================"
gcloud compute firewall-rules update allow-ssh --disabled
gcloud compute firewall-rules update allow-web --disabled

gcloud compute firewall-rules delete allow-ssh -q
gcloud compute firewall-rules delete allow-web -q


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"