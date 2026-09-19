#!/bin/bash
set -euo pipefail

# Introduction to SQL for BigQuery and Cloud SQL

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ROOT_PASSWORD=ChangeMe1!
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


# echo "======================================================================"
# echo "                  Task 1. Review the basics of SQL"
# echo "======================================================================"

# echo "======================================================================"
# echo "                Task 2. Explore the BigQuery console"
# echo "======================================================================"
# echo "----------------------------------------------------------------------"
# echo "                Use SELECT, FROM, and WHERE in BigQuery"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# "
# SELECT end_station_name
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`;
# "  > /dev/null

# bq query --use_legacy_sql=false
# "
# SELECT * 
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# WHERE duration>=1200;
# " > /dev/null

# echo "======================================================================"
# echo "Task 3. Use additional SQL Keywords: GROUP BY, COUNT, AS, and ORDER BY"
# echo "======================================================================"

# echo "----------------------------------------------------------------------"
# echo "                            GROUP BY"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# "
# SELECT start_station_name
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# GROUP BY start_station_name;
# " > /dev/null

# echo "----------------------------------------------------------------------"
# echo "                            COUNT"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# "
# SELECT start_station_name, COUNT(*)
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# GROUP BY start_station_name;
# " > /dev/null

# echo "----------------------------------------------------------------------"
# echo "                                AS"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false
# "
# SELECT start_station_name, COUNT(*) AS num_starts
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# GROUP BY start_station_name;
# "

# echo "----------------------------------------------------------------------"
# echo "                            ORDER BY"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# "
# SELECT start_station_name, COUNT(*) AS num 
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\` 
# GROUP BY start_station_name
# ORDER BY start_station_name;
# "

# bq query --use_legacy_sql=false \
# "
# SELECT start_station_name, COUNT(*) AS num
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# GROUP BY start_station_name
# ORDER BY num;
# "

# bq query --use_legacy_sql=false \
# "
# SELECT start_station_name, COUNT(*) AS num
# FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
# GROUP BY start_station_name
# ORDER BY num DESC;
# "

echo "======================================================================"
echo "            Task 4. Export BigQuery data to CSV files"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                    Exporting queries as CSV files"
echo "----------------------------------------------------------------------"

bq query --use_legacy_sql=false \
    --format=csv \
"
SELECT start_station_name, COUNT(*) AS num
FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
GROUP BY start_station_name
ORDER BY num DESC;
" > ~/start_station_name.csv


bq query --use_legacy_sql=false \
    --format=csv \
"
SELECT end_station_name, COUNT(*) AS num
FROM \`bigquery-public-data.london_bicycles.cycle_hire\`
GROUP BY end_station_name
ORDER BY num DESC;
" > ~/end_station_name.csv

echo "----------------------------------------------------------------------"
echo "                   Create a Cloud Storage bucket"
echo "----------------------------------------------------------------------"
gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID


echo "----------------------------------------------------------------------"
echo "                  Upload CSV files to Cloud Storage"
echo "----------------------------------------------------------------------"
gcloud storage cp ~/*.csv gs://$DEVSHELL_PROJECT_ID/


echo "======================================================================"
echo "              Task 5. Create a Cloud SQL instance"
echo "======================================================================"
gcloud sql instances create my-demo \
    --edition=enterprise \
    --cpu=4 \
    --memory=16GB \
    --database-version=MYSQL_8_0 \
    --zone=$ZONE \
    --availability-type=regional \
    --storage-size=100 \
    --root-password=$ROOT_PASSWORD \
    --enable-bin-log \
    --quiet
#   --tier=db-custom-4-16384 \

echo "======================================================================"
echo "            Task 6. Create a Cloud SQL database and table"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                  Connect to the Cloud SQL instance"
echo "----------------------------------------------------------------------"
# gcloud sql connect my-demo --user=root --quiet

echo "----------------------------------------------------------------------"
echo "                        Create a database"
echo "----------------------------------------------------------------------"
gcloud sql databases create bike \
    --instance=my-demo

# echo "----------------------------------------------------------------------"
# echo "                           Create a table"
# echo "----------------------------------------------------------------------"
# cat > setup.sql << EOF
# USE bike;

# CREATE TABLE IF NOT EXISTS london1 (
#     start_station_name VARCHAR(255),
#     num INT
# );

# CREATE TABLE IF NOT EXISTS london2 (
#     end_station_name VARCHAR(255),
#     num INT
# );
# EOF

# gcloud sql connect my-demo \
#     --user=root \
#     --quiet \
#     < setup.sql

# echo "======================================================================"
# echo "                 Task 7. Upload CSV files to tables"
# echo "======================================================================"
# export SQL_SA=$(gcloud sql instances describe my-demo \
#   --format="value(serviceAccountEmailAddress)")

# gcloud storage buckets add-iam-policy-binding \
#   gs://$DEVSHELL_PROJECT_ID \
#   --member="serviceAccount:$SQL_SA" \
#   --role="roles/storage.objectAdmin"

# gcloud sql import csv my-demo gs://$DEVSHELL_PROJECT_ID/start_station_name.csv \
#     --database=bike \
#     --table=london1 \
#     --quiet

# gcloud sql import csv my-demo gs://$DEVSHELL_PROJECT_ID/end_station_name.csv \
#     --database=bike \
#     --table=london2 \
#     --quiet

# echo "======================================================================"
# echo "                Task 8. Run data queries in Cloud SQL"
# echo "======================================================================"
# cat > operations.sql << EOF
# DELETE FROM london1 WHERE num=0;
# DELETE FROM london2 WHERE num=0;
# INSERT INTO london1 (start_station_name, num) VALUES ("test destination", 1);
# SELECT start_station_name AS top_stations, num FROM london1 WHERE num>100000
# UNION
# SELECT end_station_name, num FROM london2 WHERE num>100000
# ORDER BY top_stations DESC;
# EOF

# gcloud sql connect my-demo \
#     --user=root \
#     --quiet \
#     < operations.sql

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"