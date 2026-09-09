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

STORAGE_SA=$(gcloud storage service-agent --project="$DEVSHELL_PROJECT_ID" | tr -d '[:space:]')
EVENTARC_SA="service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com"
PUBSUB_SA="service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

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

sleep 10

read -p "ENTER the BUCKET NAME: " BUCKET_NAME
read -p "ENTER the TOPIC NAME: " TOPIC_NAME
read -p "ENTER the CLOUD RUN FUNCTION NAME: " CRF_NAME
read -p "ENTER the SECOND USER EMAIL: " SECOND_USER


echo "======================================================================"
echo "                      Task 1. Create a bucket"
echo "======================================================================"
gcloud storage buckets create gs://$BUCKET_NAME --location=$ZONE


echo "======================================================================"
echo "                   Task 2. Create a Pub/Sub topic"
echo "======================================================================"
gcloud pubsub topics create $TOPIC_NAME


echo "======================================================================"
echo "            Task 3. Create the thumbnail Cloud Run Function"
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

npm install

gcloud functions deploy $CRF_NAME \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=$CRF_NAME \
  --trigger-bucket=$BUCKET_NAME \
  --trigger-location=$REGION

sleep 10

curl https://storage.googleapis.com/cloud-training/gsp315/map.jpg --output map.jpg
gcloud storage cp map.jpg gs://$BUCKET_NAME
rm map.jpg


echo "======================================================================"
echo "               Task 4. Remove the previous cloud engineer"
echo "======================================================================"
gcloud projects remove-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member="user:$SECOND_USER" \
  --role="roles/viewer"


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"
