#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                 Task 1. Enable required Google Cloud APIs"
echo "======================================================================"
gcloud services enable spanner.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com

echo "======================================================================"
echo "            Task 2. Download and inspect the application code"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/training-data-analyst
cd training-data-analyst/courses/cloud-spanner/omegatrade/
cd backend/app/models
cd ../../../frontend/src/app/components

echo "======================================================================"
echo "            Task 3. Build and deploy the backend component"
echo "======================================================================"
cd ../../../../backend
cat > .env << EOF
PROJECTID = Project ID
INSTANCE = omegatrade-instance
DATABASE = omegatrade-db
JWT_KEY = w54p3Y?4dj%8Xqa2jjVC84narhe5Pk
EXPIRE_IN = 30d
EOF

nvm install 22.6
npm install npm -g
npm install --loglevel=error
docker build -t gcr.io/$PROJECT_ID/omega-trade/backend:v1 -f dockerfile.prod .
gcloud auth configure-docker --quiet

docker push gcr.io/$PROJECT_ID/omega-trade/backend:v1
gcloud run deploy omegatrade-backend --platform managed --region $REGION --image gcr.io/$PROJECT_ID/omega-trade/backend:v1 --memory 512Mi --allow-unauthenticated

echo "======================================================================"
echo "          Task 4. Import sample stock trade data to the database"
echo "======================================================================"
unset SPANNER_EMULATOR_HOST
node seed-data.js
