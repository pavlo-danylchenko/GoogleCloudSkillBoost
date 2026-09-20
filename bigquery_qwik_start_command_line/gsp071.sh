#!/bin/bash
set -euo pipefail

# BigQuery: Qwik Start - Command Line

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"


echo "======================================================================"
echo "                  Task 1. Examine a table"
echo "======================================================================"
# bq show bigquery-public-data:samples.shakespeare


echo "======================================================================"
echo "                Task 2. Run the help command"
echo "======================================================================"
# bq help query

echo "======================================================================"
echo "                     Task 3. Run a query"
echo "======================================================================"
bq query --use_legacy_sql=false \
'SELECT
    word,
    SUM(word_count) as count
FROM
    `bigquery-public-data`.samples.shakespeare
WHERE
    word LIKE "%raisin%"
GROUP BY
    word;'

bq query --use_legacy_sql=false \
'SELECT
   word
 FROM
   `bigquery-public-data`.samples.shakespeare
 WHERE
   word = "huzzah"'

echo "======================================================================"
echo "                   Task 4. Create a new table"
echo "======================================================================"
bq mk babynames

echo "----------------------------------------------------------------------"
echo "                           Upload the dataset"
echo "----------------------------------------------------------------------"
wget http://www.ssa.gov/OACT/babynames/names.zip
unzip names.zip

bq load babynames.names2010 yob2010.txt name:string,gender:string,count:integer


echo "======================================================================"
echo "                         Task 5. Run queries"
echo "======================================================================"

bq query "SELECT name,count FROM babynames.names2010 WHERE gender = 'F' ORDER BY count DESC LIMIT 5"

bq query "SELECT name,count FROM babynames.names2010 WHERE gender = 'M' ORDER BY count ASC LIMIT 5"

# bq query --use_legacy_sql=false \
# '
# SELECT name, count
# FROM babynames.names2010
# WHERE gender="F"
# ORDER BY count DESC
# LIMIT 5;
# '

# bq query --use_legacy_sql=false \
# '
# SELECT name, count
# FROM babynames.names2010
# WHERE gender="M"
# ORDER BY count ASC
# LIMIT 5;
# '

read -p "CHECK the PROGRESS of the first 6 TASKS and PRESS ANY KEY..."


echo "======================================================================"
echo "                          Task 7. Clean up"
echo "======================================================================"
bq rm -r -f babynames


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"