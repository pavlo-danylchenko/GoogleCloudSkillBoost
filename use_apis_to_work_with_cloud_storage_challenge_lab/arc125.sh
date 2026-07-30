#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export AUTH_TOKEN=$(gcloud auth print-access-token)


echo "======================================================================"
echo "            Task 1. Create two Cloud Storage buckets"
echo "======================================================================"
cat > bucket_1.json << EOF
{
    "name": "$DEVSHELL_PROJECT_ID-bucket-1",
    "location": "us",
    "storageClass": "multi_regional"
}
EOF

cat > bucket_2.json << EOF
{
    "name": "$DEVSHELL_PROJECT_ID-bucket-2",
    "location": "us",
    "storageClass": "multi_regional"
}
EOF

curl -X POST --data-binary @bucket_1.json \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://www.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID"

curl -X POST --data-binary @bucket_2.json \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://www.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID"


echo "======================================================================"
echo "      Task 2. Upload an image file to a Cloud Storage Bucket"
echo "======================================================================"
curl -LO https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/use_apis_to_work_with_cloud_storage_challenge_lab/map.jpg

curl -X POST --data-binary @map.jpg \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: image/jpg" \
    "https://storage.googleapis.com/upload/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o?uploadType=media&name=map.jpg"


echo "======================================================================"
echo "              Task 3. Copy a file to another bucket"
echo "======================================================================"
curl -X POST \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/map.jpg/copyTo/b/$DEVSHELL_PROJECT_ID-bucket-2/o/map.jpg" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  --data '{}'


echo "======================================================================"
echo "            Task 4. Make an object (file) publicly accessible"
echo "======================================================================"
cat > access.json << EOF
{
  "entity": "allUsers",
  "role": "READER"
}
EOF

curl -X POST --data-binary @access.json \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/map.jpg/acl"

curl -X POST --data-binary @access.json \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-2/o/map.jpg/acl"


# OPTIONS #2
# Create a JSON file that contains the following information:
# {
#   "bindings":[
#     {
#       "role": "roles/storage.objectViewer",
#       "members":["allUsers"]
#     }
#   ]
# }
# Use cURL to call the JSON API with a PUT Bucket request:
# curl -X PUT --data-binary @JSON_FILE_NAME \
#   -H "Authorization: Bearer $(gcloud auth print-access-token)" \
#   -H "Content-Type: application/json" \
#   "https://storage.googleapis.com/storage/v1/b/BUCKET_NAME/iam"


read -p "Check the progress and Press [ENTER] key to continue..."


echo "======================================================================"
echo " Task 5. Delete the object file and a Cloud Storage bucket (Bucket 1)"
echo "======================================================================"
curl -X DELETE \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/map.jpg" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Accept: application/json'


curl -X DELETE \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Accept: application/json'


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"