#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                Task 1. Create a Cloud Spanner instance"
echo "======================================================================"

gcloud spanner instances create banking-ops-instance \
    --config=regional-$REGION \
    --description="Banking OPS Instance" \
    --nodes=1

echo "======================================================================"
echo "               Task 2. Create a Cloud Spanner database"
echo "======================================================================"
gcloud spanner databases create banking-ops-db \
    --instance=banking-ops-instance

echo "======================================================================"
echo "                Task 3. Create tables in your database"
echo "======================================================================"

gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl='CREATE TABLE Customer (
            CustomerId STRING(36) NOT NULL,
            Name STRING(MAX) NOT NULL,
            Location STRING(MAX) NOT NULL,
        ) PRIMARY KEY (CustomerId);'

gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl='CREATE TABLE Portfolio (
            PortfolioId INT64 NOT NULL,
            Name STRING(MAX),
            ShortName STRING(MAX),
            PortfolioInfo STRING(MAX)
        ) PRIMARY KEY (PortfolioId);'

gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl='CREATE TABLE Category (
            CategoryId INT64 NOT NULL,
            PortfolioId INT64 NOT NULL,
            CategoryName STRING(MAX),
            PortfolioInfo STRING(MAX)
        ) PRIMARY KEY (CategoryId);'

gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl='CREATE TABLE Product (
            ProductId INT64 NOT NULL,
            CategoryId INT64 NOT NULL,
            PortfolioId INT64 NOT NULL,
            ProductName STRING(MAX),
            ProductAssetCode STRING(25),
            ProductClass STRING(25)
        ) PRIMARY KEY (ProductId);'

echo "======================================================================"
echo "                Task 4. Load simple datasets into tables"
echo "======================================================================"
gcloud spanner databases execute-sql banking-ops-db \
    --instance=banking-ops-instance \
    --sql="INSERT INTO Portfolio (PortfolioId, Name, ShortName, PortfolioInfo)
           VALUES
                (1, 'Banking', 'Bnkg', 'All Banking Business'),
                (2, 'Asset Growth', 'AsstGrwth', 'All Asset Focused Products'),
                (3, 'Insurance', 'Ins', 'All Insurance Focused Products');"


gcloud spanner databases execute-sql banking-ops-db \
    --instance=banking-ops-instance \
    --sql="INSERT INTO Category (CategoryId, PortfolioId, CategoryName)
           VALUES
                (1, 1, 'Cash'),
                (2, 2, 'Investments - Short Return'),
                (3, 2, 'Annuities'),
                (4, 3, 'Life Insurance');"


gcloud spanner databases execute-sql banking-ops-db \
    --instance=banking-ops-instance \
    --sql="INSERT INTO Product (ProductId, CategoryId, PortfolioId, ProductName, ProductAssetCode, ProductClass)
           VALUES
                (1, 1, 1, 'Checking Account', 'ChkAcct', 'Banking LOB'),
                (2, 2, 2, 'Mutual Fund Consumer Goods', 'MFundCG', 'Investment LOB'),
                (3, 3, 2, 'Annuity Early Retirement', 'AnnuFixed', 'Investment LOB'),
                (4, 4, 3, 'Term Life Insurance', 'TermLife', 'Insurance LOB'),
                (5, 1, 1, 'Savings Account', 'SavAcct', 'Banking LOB'),
                (6, 1, 1, 'Personal Loan', 'PersLn', 'Banking LOB'),
                (7, 1, 1, 'Auto Loan', 'AutLn', 'Banking LOB'),
                (8, 4, 3, 'Permanent Life Insurance', 'PermLife', 'Insurance LOB'),
                (9, 2, 2, 'US Savings Bonds', 'USSavBond', 'Investment LOB');"


echo "======================================================================"
echo "                   Task 5. Load a complex dataset"
echo "======================================================================"
gcloud services disable dataflow.googleapis.com --force
gcloud services enable dataflow.googleapis.com

sleep 100

cat > manifest.json << EOF
{
    "tables": [
        {
            "table_name": "Customer",
            "file_patterns": [
                "gs://$DEVSHELL_PROJECT_ID/Customer_List_500.csv"
            ],
            "columns": [
                {"column_name" : "CustomerId", "type_name" : "STRING" },
                {"column_name" : "Name", "type_name" : "STRING" },
                {"column_name" : "Location", "type_name" : "STRING" }
            ]
        }
    ]
}
EOF

gsutil mb gs://$DEVSHELL_PROJECT_ID
touch emptyfile
gsutil cp emptyfile gs://$DEVSHELL_PROJECT_ID/tmp/emptyfile

gsutil cp gs://spls/gsp381/Customer_List_500.csv gs://$DEVSHELL_PROJECT_ID/Customer_List_500.csv
gsutil cp manifest.json gs://$DEVSHELL_PROJECT_ID/manifest.json

gcloud dataflow jobs run spanner-load \
    --gcs-location gs://dataflow-templates-$REGION/latest/GCS_Text_to_Cloud_Spanner \
    --region $REGION \
    --num-workers 2 \
    --worker-machine-type e2-medium \
    --staging-location gs://$DEVSHELL_PROJECT_ID/tmp/ \
    --additional-experiments shuffle_mode=auto,use_runner_v2 \
    --parameters ^~^instanceId=banking-ops-instance~databaseId=banking-ops-db~spannerHost=https://batch-spanner.googleapis.com~importManifest=gs://$DEVSHELL_PROJECT_ID/manifest.json~columnDelimiter=,

echo "======================================================================"
echo "               Task 6. Add a new column to an existing table"
echo "======================================================================"
gcloud spanner databases ddl update banking-ops-db \
    --instance=banking-ops-instance \
    --ddl='ALTER TABLE Category ADD COLUMN MarketingBudget INT64;'


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"