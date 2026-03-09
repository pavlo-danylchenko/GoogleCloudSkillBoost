#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

# export ZONE=$(gcloud compute project-info describe \
#     --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# echo $ZONE

# export REGION=$(echo $ZONE | cut -d '-' -f 1-2)


echo "======================================================================"
echo "              Task 1. Enable the Cloud Natural Language API"
echo "======================================================================"
gcloud services enable language.googleapis.com

echo "======================================================================"
echo "                    Task 2. Create an API key"
echo "======================================================================"
gcloud services api-keys create --display-name="APIkey"

sleep 3

export KEY_UID=$(gcloud services api-keys list --filter="display_name=APIkey" --format="value(uid)")
export API_KEY=$(gcloud services api-keys get-key-string $KEY_UID --format="value(keyString)")

# Get instance zone
export ZONE=$(gcloud compute instances list --project=$DEVSHELL_PROJECT_ID \
    --format="value(ZONE)")

gcloud compute instances add-metadata linux-instance \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
#!/bin/bash

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)

echo "======================================================================"
echo "                   Task 3. Classify a news article"
echo "======================================================================"

cat > request.json << EOF_REQ
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"A Smoky Lobster Salad With a Tapa Twist. This spin on the Spanish pulpo a la gallega skips the octopus, but keeps the sea salt, olive oil, pimentón and boiled potatoes."
  }
}
EOF_REQ

echo "Analyzing text content..."
curl "https://language.googleapis.com/v1/documents:classifyText?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json

curl "https://language.googleapis.com/v1/documents:classifyText?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json > result.json

echo "The analysis is complete. The results has been saved to result.json"
EOF

echo "Sending the script to the VM instance ..."
# gcloud compute scp ./start.sh linux-instance:~/ --zone=$ZONE

# To execute once:
gcloud compute ssh linux-instance \
    --zone=$ZONE \
    --quiet \
    --project=$PROJECT_ID \
    --command="bash -s" < ./start.sh

echo "======================================================================"
echo "                 Task 4. Classify a large text dataset"
echo "======================================================================"
# gsutil cat gs://spls/gsp063/bbc_dataset/entertainment/001.txt


echo "======================================================================"
echo "        Task 5. Create a BigQuery table for categorized text data"
echo "======================================================================"
bq mk --location=US news_classification_dataset

bq mk --table news_classification_dataset.article_data \
    article_text:STRING,category:STRING,confidence:FLOAT


# echo "======================================================================"
# echo "       Task 6. Classify news data and store the result in BigQuery"
# echo "======================================================================"
# gcloud iam service-accounts create my-account --display-name my-account
# sleep 3
# gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:my-account@$PROJECT_ID.iam.gserviceaccount.com --role=roles/bigquery.admin
# gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:my-account@$PROJECT_ID.iam.gserviceaccount.com --role=roles/serviceusage.serviceUsageConsumer
# gcloud iam service-accounts keys create key.json --iam-account=my-account@$PROJECT_ID.iam.gserviceaccount.com
# export GOOGLE_APPLICATION_CREDENTIALS=key.json


# cat > classify-text.py << EOF
# from google.cloud import storage, language, bigquery

# # Set up your GCS, NL, and BigQuery clients

# storage_client = storage.Client()
# nl_client = language.LanguageServiceClient()
# bq_client = bigquery.Client(project="$PROJECT_ID")

# dataset_ref = bq_client.dataset('news_classification_dataset')
# dataset = bigquery.Dataset(dataset_ref)
# table_ref = dataset.table('article_data')
# table = bq_client.get_table(table_ref)

# # Send article text to the NL API's classifyText method

# def classify_text(article):
#     response = nl_client.classify_text(
#         document=language.Document(
#             content=article,
#             type=language.Document.Type.PLAIN_TEXT
#         )
#     )
#     return response

# rows_for_bq = []
# files = storage_client.bucket('qwiklabs-test-bucket-gsp063').list_blobs()
# print("Got article files from GCS, sending them to the NL API (this will take ~2 minutes)...")

# # Send files to the NL API and save the result to send to BigQuery

# for file in files:
#     if file.name.endswith('txt'):
#         article_text = file.download_as_bytes().decode('utf-8')  # Decode bytes to string
#         nl_response = classify_text(article_text)
#         if len(nl_response.categories) > 0:
#             rows_for_bq.append((article_text, nl_response.categories[0].name, nl_response.categories[0].confidence))

# print("Writing NL API article data to BigQuery...")

# # Write article text + category data to BQ

# if rows_for_bq:
#     errors = bq_client.insert_rows(table, rows_for_bq)
#     if errors:
#         print("Encountered errors while writing to BigQuery:", errors)
# else:
#     print("No articles found in the specified bucket.")
# EOF

# python3 classify-text.py

# bq query --use_legacy_sql=false \
#     'SELECT * FROM `$PROJECT_ID.news_classification_dataset.article_data` LIMIT 10'


# echo "======================================================================"
# echo "         Task 7. Analyze categorized news data in BigQuery"
# echo "======================================================================"
# echo "----------------------------------------------------------------------"
# echo "          Which categories were most common in the dataset"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# 'SELECT category, COUNT(*) c FROM `$PROJECT_ID.news_classification_dataset.article_data` GROUP BY category ORDER BY c DESC'

# echo "----------------------------------------------------------------------"
# echo "Find the /Arts & Entertainment/Music & Audio/Classical Music articles"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# 'SELECT * FROM `$PROJECT_ID.news_classification_dataset.article_data` WHERE category = "/Arts & Entertainment/Music & Audio/Classical Music" LIMIT 10;'

# echo "----------------------------------------------------------------------"
# echo "Get only the articles where the Natural language API returned a confidence score greater than 90%:"
# echo "----------------------------------------------------------------------"
# bq query --use_legacy_sql=false \
# 'SELECT
#   article_text,
#   category
# FROM `Project ID.news_classification_dataset.article_data`
# WHERE cast(confidence as float64) > 0.9
# LIMIT 5;'


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"