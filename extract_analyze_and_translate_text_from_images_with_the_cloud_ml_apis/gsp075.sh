#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

echo "======================================================================"
echo "              Task 00. Enable the Cloud Natural Language API"
echo "======================================================================"
# gcloud services enable vision.googleapis.com
# gcloud services enable translation.googleapis.com
# gcloud services enable language.googleapis.com

echo "======================================================================"
echo "                    Task 1. Create an API key"
echo "======================================================================"
gcloud services api-keys create \
  --display-name="APIkey" \
  --api-target=service=language.googleapis.com \
  --api-target=service=vision.googleapis.com \
  --api-target=service=translate.googleapis.com

sleep 2

export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")

# gcloud services api-keys update $KEY_UID \
#   --api-target=service=language.googleapis.com \
#   --api-target=service=vision.googleapis.com \
#   --api-target=service=translate.googleapis.com


echo "======================================================================"
echo "           Task 2. Upload an image to a Cloud Storage bucket"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                 Create a Cloud Storage bucket"
echo "----------------------------------------------------------------------"
export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket

gcloud storage buckets create gs://$BUCKET_NAME \
  --no-public-access-prevention

echo "----------------------------------------------------------------------"
echo "                 Upload an image to your bucket"
echo "----------------------------------------------------------------------"
curl -LO "https://github.com/pavlo-danylchenko/GoogleCloudSkillBoost/blob/main/extract_analyze_and_translate_text_from_images_with_the_cloud_ml_apis/sign.jpg?raw=true"
gsutil cp sign.jpg gs://$BUCKET_NAME/

echo "----------------------------------------------------------------------"
echo "                Allow the file to be viewed publicly"
echo "----------------------------------------------------------------------"
gcloud storage objects update gs://$BUCKET_NAME/sign.jpg \
    --add-acl-grant=entity=allUsers,role=READER


echo "======================================================================"
echo "             Task 3. Create your Cloud Vision API request"
echo "======================================================================"
cat > ocr-request.json << EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$BUCKET_NAME/sign.jpg"
          }
        },
        "features": [
          {
            "type": "TEXT_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF

echo "======================================================================"
echo "               Task 4. Call the text detection method"
echo "======================================================================"
curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @ocr-request.json https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}


curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @ocr-request.json https://vision.googleapis.com/v1/images:annotate?key=${API_KEY} -o ocr-response.json


echo "======================================================================"
echo "        Task 5. Send text from the image to the Translation API"
echo "======================================================================"
cat > translation-request.json << EOF
{
  "q": "your_text_here",
  "target": "en"
}
EOF

STR=$(jq .responses[0].textAnnotations[0].description ocr-response.json) \
  && STR="${STR//\"}" \
  && sed -i "s|your_text_here|$STR|g" translation-request.json

curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @translation-request.json \
  https://translation.googleapis.com/language/translate/v2?key=${API_KEY} -o translation-response.json


echo "======================================================================"
echo "   Task 6. Analyzing the image's text with the Natural Language API"
echo "======================================================================"
cat > nl-request.json << EOF
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"your_text_here"
  },
  "encodingType":"UTF8"
}
EOF

STR=$(jq .data.translations[0].translatedText  translation-response.json) \
  && STR="${STR//\"}" \
  && sed -i "s|your_text_here|$STR|g" nl-request.json


curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @nl-request.json \
  -o nl-response.json


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"