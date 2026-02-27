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

echo "======================================================================"
echo "                   Task 1. Create an instance"
echo "======================================================================"
gcloud spanner instances create test-instance \
    --config=regional-$REGION \
    --description="Test Instance" \
    --edition=ENTERPRISE \
    --processing-units=100

echo "======================================================================"
echo "                   Task 2. Create a database"
echo "======================================================================"
gcloud spanner databases create example-db \
    --instance=test-instance

echo "======================================================================"
echo "                   Task 3. Create a schema"
echo "======================================================================"
gcloud spanner databases ddl update example-db \
    --instance=test-instance \
    --ddl='CREATE TABLE Singers (
              SingerId   INT64 NOT NULL,
              FirstName  STRING(1024),
              LastName   STRING(1024),
              SingerInfo BYTES(MAX),
              BirthDate  DATE,
            ) PRIMARY KEY(SingerId);'

echo "JOB is DONE!"