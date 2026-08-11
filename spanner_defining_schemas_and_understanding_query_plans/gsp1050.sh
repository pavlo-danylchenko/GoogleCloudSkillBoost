#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                   Task 1. Load data into tables"
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
echo "      Task 2. Use pre-built Python client library code to load data"
echo "======================================================================"
mkdir python-helper
cd python-helper

wget https://storage.googleapis.com/cloud-training/OCBL373/requirements.txt
wget https://storage.googleapis.com/cloud-training/OCBL373/snippets.py

pip install -r requirements.txt
pip install setuptools

python snippets.py banking-ops-instance --database-id banking-ops-db insert_data


echo "======================================================================"
echo "              Task 3. Query data with client libraries"
echo "======================================================================"
python snippets.py banking-ops-instance --database-id banking-ops-db query_data

echo "======================================================================"
echo "                Task 4. Updating the database schema"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Adding a column using Python"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id banking-ops-db add_column

echo "----------------------------------------------------------------------"
echo "                   Write data to the new column"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id banking-ops-db update_data
python snippets.py banking-ops-instance --database-id banking-ops-db query_data_with_new_column


echo "======================================================================"
echo "                   Task 5. Add a Secondary Index"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "         Add a secondary index using the Python client library"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id banking-ops-db add_index


echo "----------------------------------------------------------------------"
echo "                       Read using the index"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id banking-ops-db read_data_with_index


echo "----------------------------------------------------------------------"
echo "                Add an index with a STORING clause"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id banking-ops-db add_storing_index
python snippets.py banking-ops-instance --database-id banking-ops-db read_data_with_storing_index


echo "======================================================================"
echo "                     Task 6. Examine Query plans"
echo "======================================================================"

echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"