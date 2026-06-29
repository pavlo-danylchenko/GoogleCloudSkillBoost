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

export BUCKET_NAME=$DEVSHELL_PROJECT_ID-bucket
echo "======================================================================"
echo "          Task 1. Clone the repo and enable APIs"
echo "======================================================================"
git clone https://github.com/googleapis/synthtool
cd synthtool/tests/fixtures/nodejs-dlp/samples/ && npm install

gcloud config set project $DEVSHELL_PROJECT_ID

gcloud services enable dlp.googleapis.com cloudkms.googleapis.com \
    --project $DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "               Task 2. Inspect strings and files"
echo "======================================================================"
node inspectString.js $DEVSHELL_PROJECT_ID "My email address is jenny@somedomain.com and you can call me at 555-867-5309" > inspected-string.txt
node inspectFile.js $DEVSHELL_PROJECT_ID resources/accounts.txt > inspected-file.txt


gsutil cp inspected-string.txt gs://$BUCKET_NAME
gsutil cp inspected-file.txt gs://$BUCKET_NAME


echo "======================================================================"
echo "                   Task 3. De-identification"
echo "======================================================================"
node deidentifyWithMask.js $DEVSHELL_PROJECT_ID "My order number is F12312399. Email me at anthony@somedomain.com" > de-identify-output.txt
gsutil cp de-identify-output.txt gs://$BUCKET_NAME


echo "======================================================================"
echo "                   Task 4. Redact strings and images"
echo "======================================================================"
node redactText.js $DEVSHELL_PROJECT_ID  "Please refund the purchase to my credit card 4012888888881881" CREDIT_CARD_NUMBER > redacted-string.txt
node redactImage.js $DEVSHELL_PROJECT_ID resources/test.png "" PHONE_NUMBER ./redacted-phone.png
node redactImage.js $DEVSHELL_PROJECT_ID resources/test.png "" EMAIL_ADDRESS ./redacted-email.png


gsutil cp redacted-string.txt gs://$BUCKET_NAME
gsutil cp redacted-phone.png gs://$BUCKET_NAME
gsutil cp redacted-email.png gs://$BUCKET_NAME


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"