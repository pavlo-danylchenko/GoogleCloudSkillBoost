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


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"
gcloud alpha services api-keys create \
    --display-name="APIkey"

KEY_NAME=$(gcloud alpha services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")


echo "======================================================================"
echo "              Task 2. Upload an image to a Cloud Storage bucket"
echo "======================================================================"
export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket
gsutil mb gs://$BUCKET_NAME

FILES=("city.png" "donuts.png" "selfie.png")

for FILE in "${FILES[@]}"
do
    echo "Uploading file: $FILE"
    curl -LO "https://raw.githubusercontent.com/pavlo-danylchenko/GoogleCloudSkillBoost/main/detect_labels_faces_and_landmarks_in_images_with_the_cloud_vision_api/$FILE"
    gsutil cp "$FILE" gs://$BUCKET_NAME
    gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME
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
              "gcsImageUri": "gs://$BUCKET_NAME-bucket/donuts.png"
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
              "gcsImageUri": "gs://$BUCKET_NAME-bucket/donuts.png"
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
              "gcsImageUri": "gs://$BUCKET_NAME-bucket/selfie.png"
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
              "gcsImageUri": "gs://$BUCKET_NAME-bucket/city.png"
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