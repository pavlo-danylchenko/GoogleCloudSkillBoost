#!/bin/bash

# Task 1. Create an API key
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)

gcloud iam service-acounts create my-natlang-sa \
    --display-name "my natural language service account"

sleep 5

gcloud iam service-accounts keys create ~/key.json \
    --iam-account my-natlang-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com

sleep 5

export GOOGLE_APPLICATION_CREDEBTIALS="/home/USER/key.json"

sleep 10

# Task 2. Make an entity analysis request
gcloud ml language analyze-entities \
    --content "Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'." > result.json

echo "Job is Done!"