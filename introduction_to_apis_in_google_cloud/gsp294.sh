#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
# export ZONE=$(gcloud compute project-info describe \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

# echo $ZONE
# echo $REGION

# gcloud config set compute/zone $ZONE
# gcloud config set compute/region $REGION

# gcloud services api-keys create --display-name="APIkey"

# export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
# export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")


echo "======================================================================"
echo "            Task 2. Creating a JSON File in the Cloud Console"
echo "======================================================================"
cat > values.json << EOF
{
    "name": "$DEVSHELL_PROJECT_ID-bucket",
    "location": "us",
    "storageClass": "multi_regional"
}
EOF


echo "======================================================================"
echo "  Task 3. Authenticate and authorize the Cloud Storage JSON/REST API"
echo "======================================================================"
export AUTH_TOKEN=$(gcloud auth print-access-token)


echo "======================================================================"
echo "     Task 4. Create a bucket with the Cloud Storage JSON/REST API"
echo "======================================================================"
curl -X POST --data-binary @values.json \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://www.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID"


echo "======================================================================"
echo "     Task 5. Upload a file using the Cloud Storage JSON/REST API"
echo "======================================================================"
curl -LO https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/introduction_to_apis_in_google_cloud/demo-image.png

curl -X POST --data-binary @demo-image.png \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: image/png" \
    "https://storage.googleapis.com/upload/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket/o?uploadType=media&name=demo-image"


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"