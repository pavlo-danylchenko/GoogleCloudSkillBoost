#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")
gcloud config set compute/region $REGION

gcloud alpha services api-keys create \
    --display-name="APIkey"


KEY_NAME=$(gcloud alpha services api-keys list --filter="display_name=APIkey" --format="value(name)")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

echo "======================================================================"
echo "                        Task 2. Translate text"
echo "======================================================================"
TEXT="My%20name%20is%20Steve"
curl "https://translation.googleapis.com/language/translate/v2?target=es&key=${API_KEY}&q=${TEXT}"


echo "======================================================================"
echo "                        Task 3. Detect the language"
echo "======================================================================"
TEXT_ONE="Meu%20nome%20é%20Steven"
TEXT_TWO="日本のグーグルのオフィスは、東京の六本木ヒルズにあります"
curl -X POST "https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}" -d "q=${TEXT_ONE}" -d "q=${TEXT_TWO}"