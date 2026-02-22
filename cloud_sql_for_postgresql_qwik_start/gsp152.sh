#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                   Task 1. Create a Cloud SQL instance"
echo "======================================================================"
gcloud sql instances create myinstance \
    --database-version=POSTGRES_15 \
    --edition=enterprise \
    --region=$REGION \
    --root-password=password123


echo "======================================================================"
echo "Task 3. Connect to the instance using the psql client in the Cloud Shell"
echo "======================================================================"
# gcloud sql connect myinstance --user=postgres


echo "======================================================================"
echo "            Task 4. Upload data into the postgres database"
echo "======================================================================"
# CREATE TABLE guestbook (guestName VARCHAR(255), content VARCHAR(255),
#                         entryID SERIAL PRIMARY KEY);
# INSERT INTO guestbook (guestName, content) values ('first guest', 'I got here!');
# INSERT INTO guestbook (guestName, content) values ('second guest', 'Me too!');
# SELECT * FROM guestbook;

echo "JOB is DONE!"