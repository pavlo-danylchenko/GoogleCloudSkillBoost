#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "             Task 1. Create a Google Cloud Storage Bucket"
echo "======================================================================"
gcloud config set project $DEVSHELL_PROJECT_ID
gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID-website --uniform-bucket-level-access


echo "======================================================================"
echo "                   Task 2. Upload Website Files"
echo "======================================================================"
cat > index.html << EOF
<html>
<head>
  <title>My Static Website</title>
</head>
<body>
  <p>Hello from Google Cloud Storage!</p>
</body>
</html>
EOF

gcloud storage cp index.html gs://$DEVSHELL_PROJECT_ID-website

echo "======================================================================"
echo "                   Task 3. Configure Bucket for Website Hosting"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Enable website configuration on the bucket"
echo "----------------------------------------------------------------------"
gcloud storage buckets update gs://$DEVSHELL_PROJECT_ID-website \
    --website-main-suffix=index.html
echo "----------------------------------------------------------------------"
echo "                   Make the bucket objects publicly readable"
echo "----------------------------------------------------------------------"
gcloud storage buckets add-iam-policy-binding gs://$DEVSHELL_PROJECT_ID-website \
    --member=allUsers --role=roles/storage.objectViewer

echo "======================================================================"
echo "                   Task 4. Access Your Website"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Get the public URL of your website"
echo "----------------------------------------------------------------------"
echo "https://storage.googleapis.com/$DEVSHELL_PROJECT_ID-website/index.html"

echo "======================================================================"
echo "                   Task 5. Clean Up"
echo "======================================================================"
# gcloud storage rm -r gs://$DEVSHELL_PROJECT_ID-website --quiet
