#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $REGION
echo $ZONE

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud services enable privilegedaccessmanager.googleapis.com \
    --project=$DEVSHELL_PROJECT_ID

read -p "Enter Requester principal: " REQUESTER_EMAIL
read -p "Enter Approver principal: " APPROVER_EMAIL


echo "======================================================================"
echo "              Task 1. Enable Privileged Access Manager"
echo "======================================================================"
ORG_ID=$(gcloud projects get-ancestors $DEVSHELL_PROJECT_ID \
    --format="value(id,type)" |
    awk '$2 == "organization" {print $1}')

# OPTION #2 - JQuery
# ORG_ID=$(gcloud projects get-ancestors $DEVSHELL_PROJECT_ID \
#     --format="json" |
#     jq -r '.[] | select(.type == "organization") | .id')

if [[ -z "$ORG_ID" ]]; then
    echo "ERROR: Could not determine Organization Number."
    exit 1
fi

PAM_SERVICE_AGENT="service-org-$ORG_ID@gcp-sa-pam.iam.gserviceaccount.com"

echo "Project: $DEVSHELL_PROJECT_ID"
echo "Organization: $ORG_ID"
echo "PAM Service Agent: $PAM_SERVICE_AGENT"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$PAM_SERVICE_AGENT" \
    --role="roles/privilegedaccessmanager.serviceAgent"


echo "======================================================================"
echo "                   Task 2. Create the entitlement"
echo "======================================================================"
cat > entitlement.yaml << EOF
privilegedAccess:
  gcpIamAccess:
    resourceType: cloudresourcemanager.googleapis.com/Project
    resource: //cloudresourcemanager.googleapis.com/projects/$DEVSHELL_PROJECT_ID
    roleBindings:
    - role: roles/compute.admin

maxRequestDuration: 36000s

eligibleUsers:
- principals:
  - user:$REQUESTER_EMAIL

approvalWorkflow:
  manualApprovals:
    requireApproverJustification: false
    steps:
    - approvalsNeeded: 1
      approvers:
      - principals:
        - user:$APPROVER_EMAIL

requesterJustificationConfig:
  unstructured: {}
EOF

gcloud pam entitlements create pam-entitlement \
    --entitlement-file=entitlement.yaml \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID

# read -p "CHECK the TASK #2 and PRESS ANY KEY..."

echo "======================================================================"
echo "                   Task 3. Update the entitlement"
echo "======================================================================"
gcloud pam entitlements export pam-entitlement \
    --destination=pam-entitlement.yaml \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID

# COPY of the response:
# cat > copy.yaml << EOF
# approvalWorkflow:
#   manualApprovals:
#     steps:
#     - approvalsNeeded: 1
#       approvers:
#       - principals:
#         - user:student-01-fcc078850e8b@qwiklabs.net
# eligibleUsers:
# - principals:
#   - user:student-01-88ba8a9e8bc2@qwiklabs.net
# etag: '"ODgwYWY1NTktOTI0OS00N2FhLWJjOWMtNTU1NDBkMmVjNDBi"'
# maxRequestDuration: 36000s
# name: projects/qwiklabs-gcp-02-3d80d41dba90/locations/global/entitlements/pam-entitlement
# privilegedAccess:
#   gcpIamAccess:
#     resource: //cloudresourcemanager.googleapis.com/projects/qwiklabs-gcp-02-3d80d41dba90
#     resourceType: cloudresourcemanager.googleapis.com/Project
#     roleBindings:
#     - role: roles/compute.admin
# requesterJustificationConfig:
#   unstructured: {}
# EOF

sed -i "s/maxRequestDuration: 36000s/maxRequestDuration: 14400s/g" pam-entitlement.yaml

gcloud pam entitlements update pam-entitlement \
    --entitlement-file=pam-entitlement.yaml \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet

# read -p "CHECK the TASK #3 and PRESS ANY KEY..."


echo "======================================================================"
echo "Task 4. Request temporary elevated access with Privileged Access Manager"
echo "======================================================================"
gcloud config set account $REQUESTER_EMAIL

GRANT_ID=$(gcloud pam grants create \
    --entitlement=pam-entitlement \
    --requested-duration=14400s \
    --justification="Testing temporary privileged access" \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID)

gcloud auth login $APPROVER_EMAIL \
    --no-launch-browser \
    --quiet

gcloud config set account $APPROVER_EMAIL

GRANT_NAME=$(gcloud pam grants search \
    --entitlement=pam-entitlement \
    --caller-relationship=can-approve \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID \
    --format="value(name)" | head -n 1)

echo "$GRANT_NAME"

GRANT_ID="${GRANT_NAME##*/}"

echo "$GRANT_ID"

gcloud pam grants approve $GRANT_ID \
    --entitlement=pam-entitlement \
    --reason="Approved for lab testing" \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID

# read -p "CHECK the TASK #4 and PRESS ANY KEY..."


echo "======================================================================"
echo "                     Task 5. Revoke a grant"
echo "======================================================================"
gcloud pam grants revoke $GRANT_ID \
    --entitlement=pam-entitlement \
    --reason="Restoring least-privilege baseline" \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID

# read -p "CHECK the TASK #5 and PRESS ANY KEY..."


echo "======================================================================"
echo "         Task 6. Delete an entitlement and review audit logs"
echo "======================================================================"
gcloud pam entitlements delete pam-entitlement \
    --location=global \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet

# OPTIONAL
# gcloud logging read \
#     'protoPayload.serviceName="privilegedaccessmanager.googleapis.com"
#      AND protoPayload.resourceName:"pam-entitlement"' \
#     --project=$DEVSHELL_PROJECT_ID \
#     --limit=50 \
#     --format=json


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"