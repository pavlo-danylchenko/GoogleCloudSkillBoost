
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
gcloud config set run/region $REGION


echo "======================================================================"
echo "               Task 1. Create a Cloud Storage bucket"
echo "======================================================================"
export BUCKET_NAME=$PROJECT_ID-kms_lab
gsutil mb gs://$BUCKET_NAME


echo "======================================================================"
echo "                     Task 2. Review the data"
echo "======================================================================"
gsutil cp gs://${GOOGLE_CLOUD_PROJECT}-kms-lab-data/finance-dept/inbox/1.txt .


echo "======================================================================"
echo "                     Task 3. Enable Cloud KMS"
echo "======================================================================"
gcloud services enable cloudkms.googleapis.com


echo "======================================================================"
echo "                  Task 4. Create a Keyring and Cryptokey"
echo "======================================================================"
export KEYRING_NAME=labkey
export CRYPTOKEY_NAME=qwiklab

gcloud kms keyrings create $KEYRING_NAME --location=global
gcloud kms keys create $CRYPTOKEY_NAME --location=global \
    --keyring=$KEYRING_NAME \
    --purpose=encryption


echo "======================================================================"
echo "                       Task 5. Encrypt your data"
echo "======================================================================"
export PLAINTEXT=$(cat 1.txt | base64 -w0)

curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)"\
  -H "Content-Type: application/json"

curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)"\
  -H "Content-Type: application/json" \
| jq .ciphertext -r > 1.encrypted


curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:decrypt" \
  -d "{\"ciphertext\":\"$(cat 1.encrypted)\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)"\
  -H "Content-Type: application/json" \
| jq .plaintext -r | base64 -d

gsutil cp 1.encrypted gs://${BUCKET_NAME}


echo "======================================================================"
echo "                    Task 6. Configure IAM permissions"
echo "======================================================================"
export USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.admin

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.cryptoKeyEncrypterDecrypter


echo "======================================================================"
echo "                Task 7. Back up data on the command line"
echo "======================================================================"
gsutil -m cp -r gs://${GOOGLE_CLOUD_PROJECT}-kms-lab-data/finance-dept .

MYDIR=finance-dept
FILES=$(find $MYDIR -type f -not -name "*.encrypted")
for file in $FILES; do
  PLAINTEXT=$(cat $file | base64 -w0)
  curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
    -d "{\"plaintext\":\"$PLAINTEXT\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
    -H "Content-Type:application/json" \
  | jq .ciphertext -r > $file.encrypted
done
gsutil -m cp finance-dept/inbox/*.encrypted gs://${BUCKET_NAME}/finance-dept/inbox

echo "======================================================================"
echo "                Task 8. View Cloud Audit logs (Optional)"
echo "======================================================================"


echo "======================================================================"
echo "                        JOB is DONE !"
echo "======================================================================"