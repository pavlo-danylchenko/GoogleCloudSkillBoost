#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                        Task 1. Create an instance"
echo "======================================================================"

export REGION=$(gcloud compute project-info describe \
                --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud spanner instances create banking-instance \
    --config=regional-$REGION \
    --description=my-instance-display-name \
    --nodes=1

echo "======================================================================"
echo "                        Task 2. Create a database"
echo "======================================================================"
gcloud spanner databases create banking-db \
    --instance=banking-instance

echo "======================================================================"
echo "                  Task 3. Create a table in your database"
echo "======================================================================"

gcloud spanner databases ddl update banking-db \
    --instance=banking-instance \
    --ddl='CREATE TABLE Customer (
            CustomerId STRING(36) NOT NULL,
            Name STRING(MAX) NOT NULL,
            Location STRING(MAX) NOT NULL,
        ) PRIMARY KEY (CustomerId);'


echo "======================================================================"
echo "                  Task 4. Insert and modify data"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                         Insert data"
echo "----------------------------------------------------------------------"

gcloud spanner databases execute-sql banking-db \
    --instance=banking-instance \
    --sql="INSERT INTO Customer (CustomerId, Name, Location)
            VALUES ('bdaaaa97-1b4b-4e58-b4ad-84030de92235',
                    'Richard Nelson',
                    'Ada Ohio');"


gcloud spanner databases execute-sql banking-db \
    --instance=banking-instance \
    --sql="INSERT INTO Customer (CustomerId, Name, Location)
            VALUES ('b2b4002d-7813-4551-b83b-366ef95f9273',
                    'Shana Underwood',
                    'Ely Iowa');"

echo "----------------------------------------------------------------------"
echo "                         Run a query"
echo "----------------------------------------------------------------------"
gcloud spanner databases execute-sql banking-db \
    --instance=banking-instance \
    --sql="SELECT * FROM Customer;"

echo "======================================================================"
echo "           Task 5. Use the Google Cloud CLI with Cloud Spanner"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                      Create an instance with CLI"
echo "----------------------------------------------------------------------"
gcloud spanner instances create banking-instance-2 \
    --config=regional-$REGION \
    --description="Banking Instance 2" \
    --nodes=2

echo "----------------------------------------------------------------------"
echo "                         Listing instances"
echo "----------------------------------------------------------------------"
gcloud spanner instances list

echo "----------------------------------------------------------------------"
echo "                         Creating a database"
echo "----------------------------------------------------------------------"
gcloud spanner databases create banking-db-2 \
    --instance=banking-instance-2

echo "----------------------------------------------------------------------"
echo "                        Modifying number of nodes"
echo "----------------------------------------------------------------------"
gcloud spanner instances update banking-instance-2 --nodes=1
gcloud spanner instances list

echo "======================================================================"
echo "           Task 6. Use Automation Tools with Cloud Spanner"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                        Create Terraform Configuration"
echo "----------------------------------------------------------------------"
cat > spanner.tf << EOF
resource "google_spanner_instance" "banking-instance-3" {
  name         = "banking-instance-3"
  config       = "regional-$REGION"
  display_name = "Banking Instance 3"
  num_nodes    = 2
  labels = {
  }
}
EOF

terraform init
terraform plan
terraform apply -auto-approve
gcloud spanner instances list

echo "======================================================================"
echo "                      Task 7. Deleting instances"
echo "======================================================================"
gcloud spanner instances delete banking-instance-2
gcloud spanner instances list

echo "Job is Done!"
