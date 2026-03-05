#!/bin/bash
set -euo pipedfail


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
gcloud config set run/region $REGION


echo "======================================================================"
echo "                    Task 1. Create a bucket"
echo "======================================================================"
gcloud storage buckets create gs://$PROJECT_ID

echo "======================================================================"
echo "                 Task 2. Upload an object into bucket"
echo "======================================================================"
curl https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg
gcloud storage cp ada.jpg gs://$PROJECT_ID
rm ada.jpg

echo "======================================================================"
echo "                Task 3. Download an object from your bucket"
echo "======================================================================"
gcloud storage cp -r gs://$PROJECT_ID/ada.jpg .


echo "======================================================================"
echo "            Task 4. Copy an object to a folder in the bucket"
echo "======================================================================"
gcloud storage cp gs://$PROJECT_ID/ada.jpg gs://$PROJECT_ID/image-folder/


echo "======================================================================"
echo "            Task 5. List contents of a bucket or folder"
echo "======================================================================"
gcloud storage ls gs://$PROJECT_ID


echo "======================================================================"
echo "                Task 6. List details for an object"
echo "======================================================================"
gcloud storage ls -l gs://$PROJECT_ID/ada.jpg


echo "======================================================================"
echo "               Task 7. Make object publicly accessible"
echo "======================================================================"
gcloud storage objects update gs://$PROJECT_ID/ada.jpg --add-acl-grant=entity=allUsers,role=READER
# gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID


echo "======================================================================"
echo "                    Task 8. Remove public access"
echo "======================================================================"
# gcloud storage objects update gs://$PROJECT_ID/ada.jpg --remove-acl-grant=allUsers


echo "----------------------------------------------------------------------"
echo "                          Delete objects"
echo "----------------------------------------------------------------------"
# gcloud storage rm -r gs://$PROJECT_ID/ada.jpg

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"