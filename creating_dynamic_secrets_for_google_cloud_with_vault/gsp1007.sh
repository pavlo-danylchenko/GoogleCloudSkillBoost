#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "                          Task 1. Install Vault"
echo "======================================================================"
# sudo apt update && sudo apt install -y curl gnupg lsb-release
# curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# sudo apt-get update
# sudo apt-get install vault

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install vault

cat > config.hcl << EOF
storage "raft" {
  path    = "./vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true

disable_mlock = true
EOF

mkdir -p ./vault/data

vault server -config=config.hcl > vault.log 2>&1 &

export VAULT_ADDR='http://127.0.0.1:8200'

export VAULT_INIT=$(vault operator init -format=json)
export VAULT_ROOT_TOKEN=$(echo $VAULT_INIT | jq -r '.root_token')
export UNSEAL_KEYS=($(echo $VAULT_INIT | jq -r '.unseal_keys_b64[]'))

export STATUS=$(vault status -format=json)
export THRESHOLD=$(echo $STATUS | jq -r '.t')

for i in $(seq 0 $THRESHOLD); do
  vault operator unseal ${UNSEAL_KEYS[$i]}
done

vault login $VAULT_ROOT_TOKEN

echo "======================================================================"
echo "             Task 2. Enable the Google Cloud secrets engine"
echo "======================================================================"
vault secrets enable gcp

echo "======================================================================"
echo "                  Task 3. Create default credentials"
echo "======================================================================"

echo "Find the email of the Qwicklabs User SA"
SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:Qwiklabs User Service Account" \
    --format="value(email)")

echo "The email is: $SA_EMAIL"
gcloud iam service-accounts keys create ~/key.json --iam-account=$SA_EMAIL


echo "======================================================================"
echo "               Task 4. Generate credentials using Vault"
echo "======================================================================"

vault write gcp/config \
credentials=@$HOME/key.json \
 ttl=3600 \
 max_ttl=86400

cat > bindings.hcl << EOF
resource "buckets/$DEVSHELL_PROJECT_ID" {
  roles = [
    "roles/storage.objectAdmin",
    "roles/storage.legacyBucketReader",
  ]
}
EOF

echo "----------------------------------------------------------------------"
echo "Configure a roleset that generates OAuth2 access tokens"
echo "----------------------------------------------------------------------"

vault write gcp/roleset/my-token-roleset \
    project="$DEVSHELL_PROJECT_ID" \
    secret_type="access_token"  \
    token_scopes="https://www.googleapis.com/auth/cloud-platform" \
    bindings=@bindings.hcl

echo "Generate the access token"
export OAUTH2_TOKEN=$(vault read -field=token gcp/roleset/my-token-roleset/token)

echo "Retrieve details of the storage bucket"
curl \
  'https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID' \
  --header 'Authorization: Bearer $OAUTH2_TOKEN' \
  --header 'Accept: application/json'

echo "Download the sample.txt file from the storage bucket"
curl -X GET \
  -H "Authorization: Bearer $OAUTH2_TOKEN" \
  -o "sample.txt" \
  "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID/o/sample.txt?alt=media"

cat sample.txt

echo "----------------------------------------------------------------------"
echo "      Configure a roleset that generates service account keys"
echo "----------------------------------------------------------------------"
vault write gcp/roleset/my-key-roleset \
    project="$DEVSHELL_PROJECT_ID" \
    secret_type="service_account_key"  \
    bindings=@bindings.hcl

echo "Generate a service account key"
vault read gcp/roleset/my-key-roleset/key

echo "----------------------------------------------------------------------"
echo "                          Static Accounts"
echo "----------------------------------------------------------------------"
vault write gcp/static-account/my-token-account \
    service_account_email="$SA_EMAIL" \
    secret_type="access_token"  \
    token_scopes="https://www.googleapis.com/auth/cloud-platform" \
    bindings=@bindings.hcl

echo "Configure a static account that generates Google Cloud service account keys"

vault write gcp/static-account/my-key-account \
    service_account_email="$SA_EMAIL" \
    secret_type="service_account_key"  \
    bindings=@bindings.hcl