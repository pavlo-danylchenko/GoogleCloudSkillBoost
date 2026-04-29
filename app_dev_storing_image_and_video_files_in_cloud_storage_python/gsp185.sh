#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set project $DEVSHELL_PROJECT_ID

echo "======================================================================"
echo "            Task 1. Prepare the quiz application"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/training-data-analyst
cd ~/training-data-analyst/courses/developingapps/python/cloudstorage/start

sed -i s/us-central/$REGION/g prepare_environment.sh
. prepare_environment.sh


echo "======================================================================"
echo "            Task 3. Create a Cloud Storage Bucket"
echo "======================================================================"
gsutil mb gs://$DEVSHELL_PROJECT_ID-media
export GCLOUD_BUCKET=$DEVSHELL_PROJECT_ID-media


echo "======================================================================"
echo "            Task 4. Adding objects to Cloud Storage"
echo "======================================================================"
cat > quiz/gcp/storage.py << EOF
import os
project_id = os.getenv('GCLOUD_PROJECT')

bucket_name = os.getenv('GCLOUD_BUCKET')

from google.cloud import storage

storage_client = storage.Client()

bucket = storage_client.get_bucket(bucket_name)

"""
Uploads a file to a given Cloud Storage bucket and returns the public url
to the new object.
"""
def upload_file(image_file, public):

    blob = bucket.blob(image_file.filename)

    blob.upload_from_string(
        image_file.read(),
        content_type=image_file.content_type)

    if public:
        blob.make_public()

    return blob.public_url
EOF

cat > quiz/webapp/questions.py << EOF
# TODO: Import the storage module

from quiz.gcp import storage, datastore

# END TODO

"""
uploads file into Google Cloud Storage
- upload file
- return public_url
"""
def upload_file(image_file, public):
    if not image_file:
        return None

    # TODO: Use the storage client to Upload the file
    # The second argument is a boolean

    public_url = storage.upload_file(
       image_file,
       public
    )

    # END TODO

    # TODO: Return the public URL
    # for the object

    return public_url

    # END TODO

"""
uploads file into Google Cloud Storage
- call method to upload file (public=true)
- call datastore helper method to save question
"""
def save_question(data, image_file):

    # TODO: If there is an image file, then upload it
    # And assign the result to a new Datastore
    # property imageUrl
    # If there isn't, assign an empty string

    if image_file:
        data['imageUrl'] = str(
                  upload_file(image_file, True))
    else:
        data['imageUrl'] = u''

    # END TODO

    data['correctAnswer'] = int(data['correctAnswer'])
    datastore.save_question(data)
    return
EOF

python run_server.py

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"