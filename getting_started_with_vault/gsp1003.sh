#!/bin/bash
set -e

# Task 1. Install Vault
sudo apt update && sudo apt install -y curl gnupg lsb-release
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update
sudo apt-get install vault

# Task 2. Start the Vault server
vault server -dev -dev-root-token-id="root" > vault.log 2>&1 &
sleep 3

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="root"

# Task 3. Create your first secret
vault kv put secret/hello foo=world
vault kv put secret/hello foo=world excited=yes
vault kv get secret/hello
vault kv get -field=foo secret/hello
vault kv get -field=excited secret/hello

vault kv get -format=json secret/hello | jq -r .data.data.excited
vault kv get -format=json secret/hello | jq -r .data.data.excited > secret.txt

gsutil cp secret.txt gs://$DEVSHELL_PROJECT_ID

# Delete secret
vault kv delete secret/hello

# Secret versions
vault kv put secret/example test=version01
vault kv put secret/example test=version02
vault kv put secret/example test=version03

vault kv get -version=2 secret/example
vault kv delete -versions=2 secret/example
vault kv undelete -versions=2 secret/example
vault kv destroy -versions=2 secret/example
vault kv get -version=2 secret/example || true

# Task 4. Secrets engines

vault kv put foo/bar a=b || true
vault secrets enable -path=kv kv
vault kv put kv/hello target=world
vault kv get kv/hello
vault kv put kv/my-secret value="s3c(eT"
vault kv get kv/my-secret
vault kv get -format=json kv/my-secret | jq -r .data.value > my-secret.txt
gsutil cp my-secret.txt gs://$DEVSHELL_PROJECT_ID
vault kv delete kv/my-secret
vault kv list kv/

vault secrets disable kv/ || true

# Task 5. Authentication
TOKEN1=$(vault token create -format=json | jq -r .auth.client_token)
vault login $TOKEN1
TOKEN2=$(vault token create -format=json | jq -r .auth.client_token)
vault token revoke $TOKEN1 || true
vault login $TOKEN1 || true

# Task 6. Auth methods
vault auth enable userpass || true
vault write auth/userpass/users/admin password=password! policies=admin
vault login -method=userpass username=admin password=password!

# Task 7. Use the Vault web UI (Transit engine)
vault secrets enable transit || true
vault write -f transit/keys/my-key

# Encrypt plain text
PLAIN_TEXT="Learn Vault!"

CIPHERTEXT=$(echo -n "$PLAINTEXT" | base64 | \
    vault write transit/encrypt/my-key -format=json plaintext=- | jq -r .data.ciphertext)

# Decrypt
DEC=$(echo -n "$CIPHERTEXT" | \
    vault write transit/decrypt/my-key -format=json ciphertext=- | jq -r .data.plaintext | base64 --decode)

echo $DEC > decrypted-string.txt

cat decrypted-string.txt
gsutil cp decrypted-string.txt gs://$DEVSHELL_PROJECT_ID

echo "Job is Done!"