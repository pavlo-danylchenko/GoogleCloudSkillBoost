#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

# gcloud services list --filter="name=storage.googleapis.com"
# gcloud services list --filter="name=run.googleapis.com"
# gcloud services list --filter="name=eventarc.googleapis.com"
# gcloud services list --filter="name=cloudfunctions.googleapis.com"

# gcloud services enable \
#     run.googleapis.com \
#     eventarc.googleapis.com \
#     cloudfunctions.googleapis.com

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

STORAGE_SA="service-$PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com"
EVENTARC_SA="service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com"
PUBSUB_SA="service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
# PUBSUB_SA=$(gcloud storage service-agent --project=$DEVSHELL_PROJECT_ID)
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

echo "PROJECT_NUMBER: $PROJECT_NUMBER"
echo "EVENTARC_SA: $EVENTARC_SA"
echo "PUBSUB_SA: $PUBSUB_SA"
echo "STORAGE_SA: $STORAGE_SA"
echo "COMPUTE_SA: $COMPUTE_SA"

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

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
    --member="serviceAccount:$PUBSUB_SA" \
    --role="roles/iam.serviceAccountTokenCreator"

sleep 15

# read -p "ENTER the BUCKET NAME: " BUCKET_NAME
read -p "ENTER the TOPIC NAME: " TOPIC_NAME
read -p "ENTER the CLOUD RUN FUNCTION NAME: " CRF_NAME

export BUCKET_NAME="memories-bucket-$DEVSHELL_PROJECT_ID"
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
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { PubSub } = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('$CRF_NAME', async cloudEvent => {
  const event = cloudEvent.data;

  console.log(\`Event: \${JSON.stringify(event)}\`);
  console.log(\`Hello \${event.bucket}\`);

  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();

  if (fileName.search("64x64_thumbnail") === -1) {
    // doesn't have a thumbnail, get the filename extension
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1); // fix sub string to remove the dot

    if (filename_ext === 'png' || filename_ext === 'jpg' || filename_ext === 'jpeg') {
      // only support png and jpg at this point
      console.log(\`Processing Original: gs://\${bucketName}/\${fileName}\`);
      const gcsObject = bucket.file(fileName);
      const newFilename = \`\${filename_without_ext}_64x64_thumbnail.\${filename_ext}\`;
      const gcsNewObject = bucket.file(newFilename);

      try {
        const [buffer] = await gcsObject.download();
        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .toFormat(filename_ext)
          .toBuffer();

        await gcsNewObject.save(resizedBuffer, {
          metadata: {
            contentType: \`image/\${filename_ext}\`,
          },
        });

        console.log(\`Success: \${fileName} → \${newFilename}\`);

        await pubsub
          .topic(topicName)
          .publishMessage({ data: Buffer.from(newFilename) });

        console.log(\`Message published to \${topicName}\`);
      } catch (err) {
        console.error(\`Error: \${err}\`);
      }
    } else {
      console.log(\`gs://\${bucketName}/\${fileName} is not an image I can handle\`);
    }
  } else {
    console.log(\`gs://\${bucketName}/\${fileName} already has a thumbnail\`);
  }
});
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
   "@google-cloud/functions-framework": "^3.0.0",
   "@google-cloud/pubsub": "^2.0.0",
   "@google-cloud/storage": "^6.11.0",
   "sharp": "^0.32.1"
 },
 "devDependencies": {},
 "engines": {
   "node": ">=4.3.2"
 }
}
EOF

gcloud functions deploy $CRF_NAME \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=$CRF_NAME \
  --trigger-bucket=$BUCKET_NAME \
  --trigger-location=$REGION
#   --allow-unauthenticated

echo "======================================================================"
echo "                    Task 4. Test the Infrastructure"
echo "======================================================================"
curl https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg
gcloud storage cp ada.jpg gs://$BUCKET_NAME
rm ada.jpg

 
echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"