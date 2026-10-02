#!/bin/bash
set -euo pipefail

# APIs Explorer: Qwik Start

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

# gcloud services enable \
#     vision.googleapis.com

# export PROJECT_ID=$(gcloud config get-value project)

# export ZONE=$(gcloud compute project-info describe \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# echo $ZONE

# export REGION=$(echo $ZONE | cut -d '-' -f 1-2)


echo "======================================================================"
echo "              Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket

gcloud storage buckets create gs://$BUCKET_NAME \
    --location=US \
    --no-public-access-prevention

# gcloud storage buckets update gs://$BUCKET_NAME \
#     --no-uniform-bucket-level-access


echo "======================================================================"
echo "                      Task 2. Upload an image"
echo "======================================================================"

curl -LO "https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/apis_explorer_qwik_start/demo-image.jpg"

gcloud storage cp demo-image.jpg gs://$BUCKET_NAME

gcloud storage objects update gs://$BUCKET_NAME/demo-image.jpg \
    --add-acl-grant=entity=allUsers,role=READER


echo "======================================================================"
echo "         Task 3. Make a request to the Cloud Vision API service"
echo "======================================================================"
# cat > request.json << EOF
# {
#     "requests": [
#         {
#             "features": [
#                 {
#                     "type": "LABEL_DETECTION"
#                 }
#             ],
#             "image": {
#                 "source": {
#                     "imageUri": "gs://$BUCKET_NAME/demo-image.jpg"
#                 }
#             }
#         }
#     ]
# }
# EOF

# export TOKEN=$(gcloud auth print-access-token)

# curl --request POST \
#   'https://vision.googleapis.com/v1/images:annotate' \
#   --header "Authorization: Bearer $TOKEN" \
#   --header "Accept: application/json" \
#   --header "Content-Type: application/json" \
#   --data  @request.json \
#   --compressed

echo "======================================================================"
echo "          JOB is DONE !!!"
echo "======================================================================"