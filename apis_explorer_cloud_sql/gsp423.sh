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
echo "       Task 1. Build a Cloud SQL instance with instances.insert"
echo "======================================================================"
gcloud services enable sqladmin.googleapis.com
export AUTH_TOKEN=$(gcloud auth print-access-token)

# OPTION #1
curl --request POST \
  "https://sqladmin.googleapis.com/sql/v1beta4/projects/$PROJECT_ID/instances" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{'name':'my-instance','settings':{'tier':'db-n1-standard-1'},'region':\"$REGION\"}" \
  --compressed


# OPTION #2
# gcloud sql instances create my-instance \
#   --project=$PROJECT_ID \
#   --region=$REGION \
#   --database-version=MYSQL_8_0 \
#   --tier=db-n1-standard-1

echo "======================================================================"
echo "          Task 2. Create a database with databases.insert"
echo "======================================================================"

# OPTION #1
curl --request POST \
  "https://sqladmin.googleapis.com/sql/v1beta4/projects/$PROJECT_ID/instances/my-instance/databases" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data "{'instance':'my-instance','name':'mysql-db','project':'$PROJECT_ID'}" \
  --compressed

# OPTION #2
# gcloud sql databases create mysql-db \
#     --instance=my-instance \
#     --project=$PROJECT_ID


echo "======================================================================"
echo "Task 3. Create a table in your MySQL database and upload a CSV file to a Cloud Storage bucket"
echo "======================================================================"
# OPTION # 1
# curl -X POST \
#     -H "Authorization: Bearer $AUTH_TOKEN" \
#     -H "Content-Type: application/json" \
#     "https://sqladmin.googleapis.com/v1/projects/$PROJECT_ID/instances/my-instance/executeSql" \
#     -d '{
#       "sqlStatement": "CREATE TABLE info (name VARCHAR(255), age INT, occupation VARCHAR(255));",
#       "database": "mysql-db",
#       "user": "root"
#     }'


# OPTION #2
# echo "USE \`mysql-db\`; CREATE TABLE info (name VARCHAR(255), age INT, occupation VARCHAR(255));" | \
#     gcloud sql connect my-instance --user=root --quiet

echo "USE mysql-db; CREATE TABLE info (name VARCHAR(255), age INT, occupation VARCHAR(255));" > create_table.sql
gcloud sql connect my-instance --user=root < create_table.sql

cat > employee_info.csv << EOF
"Sean", 23, "Content Creator"
"Emily", 34, "Cloud Engineer"
"Rocky", 40, "Event coordinator"
"Kate", 28, "Data Analyst"
"Juan", 51, "Program Manager"
"Jennifer", 32, "Web Developer"
EOF

gsutil mb gs://$PROJECT_ID
gsutil cp employee_info.csv gs://$PROJECT_ID


export SQL_SA=$(gcloud sql instances describe my-instance \
    --format="value(serviceAccountEmailAddress)")

echo "Service Account for Cloud SQL: $SQL_SA"

gcloud storage buckets add-iam-policy-binding gs://$PROJECT_ID \
    --member="serviceAccount:$SQL_SA" \
    --role="roles/storage.admin"


echo "======================================================================"
echo "    Task 4. Add a CSV file to your database using instances.import"
echo "======================================================================"
#  OPTION #1
curl --request POST \
  "https://sqladmin.googleapis.com/sql/v1beta4/projects/$PROJECT_ID/instances/my-instance/import" \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data "{'importContext':{'database':'mysql-db','uri':'gs://$PROJECT_ID/employee_info.csv','fileType':'CSV','csvImportOptions':{'table':'info'}}}" \
  --compressed

#  OPTION #2
# gcloud sql import csv my-instance gs://$PROJECT_ID/employee_info.csv \
#     --database=mysql-db \
#     --table=info \
#     --columns=name,age,occupation \
#     --quiet

echo "======================================================================"
echo "                Task 6. Delete your database"
echo "======================================================================"
# OPTION #1
# curl --request DELETE \
#   "https://sqladmin.googleapis.com/sql/v1beta4/projects/$PROJECT_ID/instances/my-instance/databases/mysql-db" \
#   --header "Authorization: Bearer $AUTH_TOKEN" \
#   --header 'Accept: application/json' \
#   --compressed


echo "Job is Done !"
