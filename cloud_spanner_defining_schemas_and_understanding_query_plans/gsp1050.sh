#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                 Task 1. Load data into tables"
echo "======================================================================"
SQL_QUERIES="
        insert into Portfolio (PortfolioId, Name, ShortName, PortfolioInfo) values (1, "Banking", "Bnkg", "All Banking Business");
        insert into Portfolio (PortfolioId, Name, ShortName, PortfolioInfo) values (2, "Asset Growth", "AsstGrwth", "All Asset Focused Products");
        insert into Portfolio (PortfolioId, Name, ShortName, PortfolioInfo) values (3, "Insurance", "Ins", "All Insurance Focused Products");
        insert into Category (CategoryId,PortfolioId,CategoryName) values (1,1,"Cash");
        insert into Category (CategoryId,PortfolioId,CategoryName) values (2,2,"Investments - Short Return");
        insert into Category (CategoryId,PortfolioId,CategoryName) values (3,2,"Annuities");
        insert into Category (CategoryId,PortfolioId,CategoryName) values (4,3,"Life Insurance");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (1,1,1,"Checking Account","ChkAcct","Banking LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (2,2,2,"Mutual Fund Consumer Goods","MFundCG","Investment LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (3,3,2,"Annuity Early Retirement","AnnuFixed","Investment LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (4,4,3,"Term Life Insurance","TermLife","Insurance LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (5,1,1,"Savings Account","SavAcct","Banking LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (6,1,1,"Personal Loan","PersLn","Banking LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (7,1,1,"Auto Loan","AutLn","Banking LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (8,4,3,"Permanent Life Insurance","PermLife","Insurance LOB");
        insert into Product (ProductId,CategoryId,PortfolioId,ProductName,ProductAssetCode,ProductClass) values (9,2,2,"US Savings Bonds","USSavBond","Investment LOB");
"

IFS=';' read -ra ADDR <<< "$SQL_QUERIES"
for query in "${ADDR[@]}"; do
    trimmed_query=$(echo "$query" | xargs)
    
    if [ -n "$trimmed_query" ]; then
        gcloud spanner databases execute-sql banking-ops-db \
            --instance=banking-ops-instance \
            --sql="$trimmed_query"
    fi
done

echo "======================================================================"
echo "    Task 2. Use pre-built Python client library code to load data"
echo "======================================================================"
mkdir python-helper
cd python-helper

wget https://storage.googleapis.com/cloud-training/OCBL373/requirements.txt
wget https://storage.googleapis.com/cloud-training/OCBL373/snippets.py

pip install -r requirements.txt
pip install setuptools

python snippets.py banking-ops-instance --database-id banking-ops-db insert_data


echo "======================================================================"
echo "           Task 3. Query data with client libraries"
echo "======================================================================"
python snippets.py banking-ops-instance --database-id  banking-ops-db query_data


echo "======================================================================"
echo "             Task 4. Updating the database schema"
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
echo "                Task 5. Add a Secondary Index"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "           Add a secondary index using the Python client library"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id  banking-ops-db add_index

echo "----------------------------------------------------------------------"
echo "                     Read using the index"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id  banking-ops-db read_data_with_index

echo "----------------------------------------------------------------------"
echo "                  Add an index with a STORING clause"
echo "----------------------------------------------------------------------"
python snippets.py banking-ops-instance --database-id  banking-ops-db add_storing_index
python snippets.py banking-ops-instance --database-id  banking-ops-db read_data_with_storing_index
