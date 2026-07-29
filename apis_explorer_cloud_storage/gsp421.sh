#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
# export ZONE=$(gcloud compute project-info describe \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# echo $ZONE

# export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

# gcloud config set compute/zone $ZONE
# gcloud config set compute/region $REGION


# gcloud services api-keys create --display-name="APIkey"

# export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
# export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")

export AUTH_TOKEN=$(gcloud auth print-access-token)

echo "======================================================================"
echo "                Task 1. Create Cloud Storage Buckets"
echo "======================================================================"
curl --request POST \
  "https://storage.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data "{'name':'$DEVSHELL_PROJECT_ID'}" \
  --compressed

echo "======================================================================"
echo "                Task 2. Make a second Cloud Storage bucket"
echo "======================================================================"
curl --request POST \
  "https://storage.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data "{'name':'$DEVSHELL_PROJECT_ID-2'}" \
  --compressed


echo "======================================================================"
echo "            Task 3. Upload files to your Cloud Storage bucket"
echo "======================================================================"
curl -LO https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/apis_explorer_cloud_storage/demo-image1.png
curl -LO https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/apis_explorer_cloud_storage/demo-image2.png


curl -X POST --data-binary @demo-image1.png \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: image/png" \
    "https://storage.googleapis.com/upload/storage/v1/b/$DEVSHELL_PROJECT_ID/o?uploadType=media&name=demo-image1.png"


curl -X POST --data-binary @demo-image2.png \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: image/png" \
    "https://storage.googleapis.com/upload/storage/v1/b/$DEVSHELL_PROJECT_ID/o?uploadType=media&name=demo-image2.png"


echo "======================================================================"
echo "            Task 4. Copy files between Cloud Storage buckets"
echo "======================================================================"
curl --request POST \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID/o/demo-image1.png/copyTo/b/$DEVSHELL_PROJECT_ID-2/o/demo-image1-copy.png" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{}' \
  --compressed

read -p "Check the progress and Press [ENTER] key to continue..."

echo "======================================================================"
echo "            Task 5. Delete files from a Cloud Storage bucket"
echo "======================================================================"
curl --request DELETE \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID/o/demo-image1.png" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --compressed

curl --request DELETE \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID/o/demo-image2.png" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --compressed

read -p "Check the progress and Press [ENTER] key to continue..."

echo "======================================================================"
echo "              Task 6. Delete your Cloud Storage bucket"
echo "======================================================================"
curl --request DELETE \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --compressed


echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"