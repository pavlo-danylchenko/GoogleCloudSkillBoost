#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"
gcloud services api-keys create \
  --display-name="APIkey" \
  --api-target=service=vision.googleapis.com

export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")

echo "======================================================================"
echo "              Task 2. Upload an image to a Cloud Storage bucket"
echo "======================================================================"
export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket
# gsutil mb gs://$BUCKET_NAME

gcloud storage buckets create gs://$BUCKET_NAME \
  --no-public-access-prevention

FILES=("city.png" "donuts.png" "selfie.png")

for FILE in "${FILES[@]}"
do
    echo "Uploading file: $FILE"
    curl -LO "https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/main/detect_labels_faces_and_landmarks_in_images_with_the_cloud_vision_api/$FILE"
    gsutil cp "$FILE" gs://$BUCKET_NAME
    
    gcloud storage objects update gs://$BUCKET_NAME/$FILE \
      --add-acl-grant=entity=allUsers,role=READER
    
    # gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME/$FILE
    # gsutil acl ch -u AllUsers:R gs://$BUCKET_NAME/$FILE
done


echo "======================================================================"
echo "                    Task 3. Create your request"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$BUCKET_NAME/donuts.png"
          }
        },
        "features": [
          {
            "type": "LABEL_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF


echo "======================================================================"
echo "                    Task 4. Perform label detection"
echo "======================================================================"
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
    https://vision.googleapis.com/v1/images:annotate?key=${API_KEY} -o label_detection.json && cat label_detection.json


echo "======================================================================"
echo "                    Task 5. Perform web detection"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$BUCKET_NAME/donuts.png"
          }
        },
        "features": [
          {
            "type": "WEB_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
    https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}


echo "======================================================================"
echo "                    Task 6. Perform face detection"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$BUCKET_NAME/selfie.png"
          }
        },
        "features": [
          {
            "type": "FACE_DETECTION"
          },
          {
            "type": "LANDMARK_DETECTION"
          }
        ]
      }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json  \
    https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}


echo "======================================================================"
echo "                    Task 7. Perform landmark annotation"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$BUCKET_NAME/city.png"
          }
        },
        "features": [
          {
            "type": "LANDMARK_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json  \
    https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}


echo "======================================================================"
echo "                    Task 8. Perform object localization"
echo "======================================================================"
cat > request.json << EOF
{
  "requests": [
    {
      "image": {
        "source": {
          "imageUri": "https://cloud.google.com/vision/docs/images/bicycle_example.png"
        }
      },
      "features": [
        {
          "maxResults": 10,
          "type": "OBJECT_LOCALIZATION"
        }
      ]
    }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
    https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"