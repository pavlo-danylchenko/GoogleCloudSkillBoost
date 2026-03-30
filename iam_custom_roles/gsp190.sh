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
echo "               Task 4. Create a custom role"
echo "======================================================================"

cat > role-definition.yaml << EOF
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF

gcloud iam roles create editor --project $DEVSHELL_PROJECT_ID \
    --file role-definition.yaml


echo "----------------------------------------------------------------------"
echo "                 Create a custom role using flags"
echo "----------------------------------------------------------------------"
gcloud iam roles create viewer --project $DEVSHELL_PROJECT_ID \
    --title "Role Viewer" --description "Custom role description." \
    --permissions compute.instances.get,compute.instances.list --stage ALPHA


echo "======================================================================"
echo "                  Task 5. List the custom roles"
echo "======================================================================"
# gcloud iam roles list --project $DEVSHELL_PROJECT_ID
# gcloud iam roles list

echo "======================================================================"
echo "                Task 6. Update an existing custom role"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "               Update a custom role using a YAML file"
echo "----------------------------------------------------------------------"
cat > new-role-definition.yaml << EOF
description: Edit access for App Versions
etag:
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
- storage.buckets.get
- storage.buckets.list
name: projects/$DEVSHELL_PROJECT_ID/roles/editor
stage: ALPHA
title: Role Editor
EOF

gcloud iam roles update editor --project $DEVSHELL_PROJECT_ID \
    --file new-role-definition.yaml --quiet

echo "----------------------------------------------------------------------"
echo "                  Update a custom role using flags"
echo "----------------------------------------------------------------------"
gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
    --add-permissions storage.buckets.get,storage.buckets.list


echo "======================================================================"
echo "                   Task 7. Disable a custom role"
echo "======================================================================"
gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
--stage DISABLED

echo "======================================================================"
echo "                   Task 8. Delete a custom role"
echo "======================================================================"
gcloud iam roles delete viewer --project $DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "                   Task 9. Restore a custom role"
echo "======================================================================"
gcloud iam roles undelete viewer --project $DEVSHELL_PROJECT_ID

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"

