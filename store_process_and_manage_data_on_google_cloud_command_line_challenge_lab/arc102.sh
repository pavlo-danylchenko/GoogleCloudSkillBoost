#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

for SERVICE in \
    eventarc.googleapis.com \
    pubsub.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com
do
    echo "Enabling SERVICE: $SERVICE"
    gcloud services enable $SERVICE
    
    echo "Creating service identity: $SERVICE"
    gcloud beta services identity create \
        --service=$SERVICE \
        --project=$DEVSHELL_PROJECT_ID \
        --quiet
done

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION

PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID \
    --format="value(projectNumber)")

# Three ways to GET STORAGE SA
# STORAGE_SA="service-$PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com"
# STORAGE_SA=$(gsutil kms serviceaccount -p $DEVSHELL_PROJECT_ID)
# STORAGE_SA=$(gcloud storage service-agent --project=$DEVSHELL_PROJECT_ID)

STORAGE_SA=$(gcloud storage service-agent --project="$DEVSHELL_PROJECT_ID" | tr -d '[:space:]')

# STORAGE_SA="service-$PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com"
EVENTARC_SA="service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com"
PUBSUB_SA="service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
# PUBSUB_SA=$(gcloud storage service-agent --project=$DEVSHELL_PROJECT_ID)
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

echo "PROJECT_NUMBER: $PROJECT_NUMBER"
echo "EVENTARC_SA: $EVENTARC_SA"
echo "PUBSUB_SA: $PUBSUB_SA"
echo "STORAGE_SA: $STORAGE_SA"
echo "COMPUTE_SA: $COMPUTE_SA"

sleep 15

# Grant Compute Engine default service account Event Receiver role
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$COMPUTE_SA" \
    --role="roles/eventarc.eventReceiver"

# Grant Storage Service Account Publisher role
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$STORAGE_SA" \
    --role="roles/pubsub.publisher"

# Grant Eventarc Service Agent role
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$EVENTARC_SA" \
    --role="roles/eventarc.serviceAgent"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member="serviceAccount:$PUBSUB_SA" \
    --role="roles/iam.serviceAccountTokenCreator"

sleep 25

read -p "ENTER the BUCKET NAME: " BUCKET_NAME
read -p "ENTER the TOPIC NAME: " TOPIC_NAME
read -p "ENTER the CLOUD RUN FUNCTION NAME: " CRF_NAME

# export BUCKET_NAME="memories-bucket-$DEVSHELL_PROJECT_ID"
# export CRF_NAME="memories-thumbnail-maker"


echo "======================================================================"
echo "                       Task 1. Create a bucket"
echo "======================================================================"
gsutil mb -l $REGION gs://$BUCKET_NAME
# gcloud storage buckets create gs://$PROJECT_ID

echo "======================================================================"
echo "                   Task 2. Create a Pub/Sub topic"
echo "======================================================================"
gcloud pubsub topics create $TOPIC_NAME
# gcloud pubsub subscriptions create $TOPIC_NAME-sub --tsopic $TOPIC_NAME


echo "======================================================================"
echo "           Task 3. Create the thumbnail Cloud Run function"
echo "======================================================================"
mkdir ~/cloud-storage && cd $_
cat > index.js << EOF
/* globals exports, require */
//jshint strict: false
//jshint esversion: 6
"use strict";
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

exports.thumbnail = (event, context) => {
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64"
  const bucket = gcs.bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();
  if ( fileName.search("64x64_thumbnail") == -1 ){
    // doesn't have a thumbnail, get the filename extension
    var filename_split = fileName.split('.');
    var filename_ext = filename_split[filename_split.length - 1];
    var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length );
    if (filename_ext.toLowerCase() == 'png' || filename_ext.toLowerCase() == 'jpg'){
      // only support png and jpg at this point
      console.log(\`Processing Original: gs://\${bucketName}/\${fileName}\`);
      const gcsObject = bucket.file(fileName);
      let newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
      let gcsNewObject = bucket.file(newFilename);
      let srcStream = gcsObject.createReadStream();
      let dstStream = gcsNewObject.createWriteStream();
      let resize = imagemagick().resize(size).quality(90);
      srcStream.pipe(resize).pipe(dstStream);
      return new Promise((resolve, reject) => {
        dstStream
          .on("error", (err) => {
            console.log(\`Error: \${err}\`);
            reject(err);
          })
          .on("finish", () => {
            console.log(\`Success: \${fileName} → \${newFilename}\`);
              // set the content-type
              gcsNewObject.setMetadata(
              {
                contentType: 'image/'+ filename_ext.toLowerCase()
              }, function(err, apiResponse) {});
              pubsub
                .topic(topicName)
                .publisher()
                .publish(Buffer.from(newFilename))
                .then(messageId => {
                  console.log(\`Message \${messageId} published.\`);
                })
                .catch(err => {
                  console.error('ERROR:', err);
                });
          });
      });
    }
    else {
      console.log(\`gs://\${bucketName}/\${fileName} is not an image I can handle\`);
    }
  }
  else {
    console.log(\`gs://\${bucketName}/\${fileName} already has a thumbnail\`);
  }
};
EOF

cat > package.json << EOF
{
  "name": "thumbnails",
  "version": "1.0.0",
  "description": "Create Thumbnail of uploaded image",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^5.0.0",
    "fast-crc32c": "1.0.4",
    "imagemagick-stream": "4.1.1"
  },
  "devDependencies": {},
  "engines": {
    "node": ">=4.3.2"
  }
}
EOF

npm install

gcloud functions deploy $CRF_NAME \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=thumbnail \
  --trigger-bucket=$BUCKET_NAME \
  --trigger-location=$REGION

# gcloud functions deploy nodejs-pubsub-function \
#   --gen2 \
#   --runtime=node_gcp_runtime \
#   --region=REGION \
#   --source=. \
#   --entry-point=helloPubSub \
#   --trigger-topic cf-demo \
#   --stage-bucket PROJECT_ID-bucket \
#   --service-account cloudfunctionsa@PROJECT_ID.iam.gserviceaccount.com \
#   --allow-unauthenticated

echo "======================================================================"
echo "                    Task 4. Test the Infrastructure"
echo "======================================================================"
# curl https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg
curl https://storage.googleapis.com/cloud-training/arc101/travel.jpg --output travel.jpg
curl https://storage.googleapis.com/cloud-training/arc102/wildlife.jpg --output wildlife.jpg
gcloud storage cp travel.jpg gs://$BUCKET_NAME
gcloud storage cp wildlife.jpg gs://$BUCKET_NAME
rm travel.jpg
rm wildlife.jpg

 
echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"