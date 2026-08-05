#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                      Task 1. Explore the instance"
echo "======================================================================"


echo "======================================================================"
echo "                      Task 2. Insert data with DML"
echo "======================================================================"
gcloud spanner databases execute-sql banking-db \
    --instance=banking-instance \
    --sql="INSERT INTO Customer (CustomerId, Name, Location)
           VALUES
           ('bdaaaa97-1b4b-4e58-b4ad-84030de92235', 'Richard Nelson', 'Ada Ohio')"

sleep 10

echo "======================================================================"
echo "                Task 3. Insert data through a client library"
echo "======================================================================"
cat > insert.py << EOF
from google.cloud import spanner
from google.cloud.spanner_v1 import param_types

INSTANCE_ID = "banking-instance"
DATABASE_ID = "banking-db"

spanner_client = spanner.Client()
instance = spanner_client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)

def insert_customer(transaction):
    row_ct = transaction.execute_update(
        "INSERT INTO Customer (CustomerId, Name, Location)"
        "VALUES ('b2b4002d-7813-4551-b83b-366ef95f9273', 'Shana Underwood', 'Ely Iowa')"
    )
    print("{} record(s) inserted.".format(row_ct))

database.run_in_transaction(insert_customer)
EOF

python3 insert.py

sleep 10

echo "======================================================================"
echo "          Task 4. Insert batch data through a client library"
echo "======================================================================"
cat > batch_insert.py << EOF
from google.cloud import spanner
from google.cloud.spanner_v1 import param_types

INSTANCE_ID = "banking-instance"
DATABASE_ID = "banking-db"

spanner_client = spanner.Client()
instance = spanner_client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)

with database.batch() as batch:
    batch.insert(
        table="Customer",
        columns=("CustomerId", "Name", "Location"),
        values=[
        ('edfc683f-bd87-4bab-9423-01d1b2307c0d', 'John Elkins', 'Roy Utah'),
        ('1f3842ca-4529-40ff-acdd-88e8a87eb404', 'Martin Madrid', 'Ames Iowa'),
        ('3320d98e-6437-4515-9e83-137f105f7fbc', 'Theresa Henderson', 'Anna Texas'),
        ('6b2b2774-add9-4881-8702-d179af0518d8', 'Norma Carter', 'Bend Oregon'),

        ],
    )

print("Rows inserted")
EOF

python3 batch_insert.py

echo "======================================================================"
echo "               Task 5. Load data using Dataflow"
echo "======================================================================"
gsutil mb gs://$DEVSHELL_PROJECT_ID
touch emptyfile
gsutil cp emptyfile gs://$DEVSHELL_PROJECT_ID/tmp/emptyfile

gcloud services disable dataflow.googleapis.com --force
gcloud services enable dataflow.googleapis.com

sleep 15

gcloud dataflow jobs run spanner-load \
    --gcs-location gs://dataflow-templates-$REGION/latest/GCS_Text_to_Cloud_Spanner \
    --region $REGION \
    --num-workers 2 \
    --worker-machine-type e2-medium \
    --staging-location gs://$DEVSHELL_PROJECT_ID/tmp/ \
    --additional-experiments shuffle_mode=auto,use_runner_v2 \
    --parameters ^~^instanceId=banking-instance~databaseId=banking-db~spannerHost=https://batch-spanner.googleapis.com~importManifest=gs://spls/gsp1049/manifest.json~columnDelimiter=,
    # --parameters ^~^instanceId=banking-instance~databaseId=banking-db~spannerHost=https://batch-spanner.googleapis.com~importManifest=gs://spls/gsp1049/manifest.json~columnDelimiter=,~fieldQualifier="~trailingDelimiter=true~handleNewLine=false~maxNumRows=500


echo "CHECK JOB STATUS: https://console.cloud.google.com/dataflow/jobs?project=$DEVSHELL_PROJECT_ID"


echo "======================================================================"
echo "                   Task 6. Backup your database"
echo "======================================================================"
# gcloud spanner backups create banking-backup-001 \
#     --instance=banking-instance \
#     --database=banking-db \
#     --retention-period=1y

echo "======================================================================"
echo "                            JOB is DONE!"
echo "======================================================================"