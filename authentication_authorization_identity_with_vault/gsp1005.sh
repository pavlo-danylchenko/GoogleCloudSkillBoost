#!/bin/bash
set -euo pipefail

echo "Task 1. Install Vault"
echo "Add the HashiCorp GPG key"
sudo apt update && sudo apt install -y curl gnupg lsb-release
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "Add the HashiCorp repository to your system's sources list" 
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update
sudo apt-get install vault -y

echo "Vault version is $(vault --version)"

echo "Task 2. Start the Vault server"
vault server -dev -dev-root-token-id="root" > vault.log 2>&1 &
sleep 3

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="root"

echo "Task 3. Authentication in Vault"
echo "Task 4. AppRole auth method overview"
echo "Task 5. Using the AppRole auth method"
echo "Create some test data"
vault kv put secret/mysql/webapp db_name="users" username="admin" password="passw0rd"

vault auth enable approle || true

echo "Create a jenkins policy file"
vault policy write jenkins -<<EOF
# Read-only permission on secrets stored at 'secret/data/mysql/webapp'
path "secret/data/mysql/webapp" {
  capabilities = [ "read" ]
}
EOF

echo "Create a role named jenkins with jenkins policy attached"
vault write auth/approle/role/jenkins token_policies="jenkins" \
    token_ttl=1h token_max_ttl=4h

vault read auth/approle/role/jenkins
echo "Retrieve the RoleID and SecretID for the jenkins role"
export ROLE_ID=$(vault read  -field=role_id auth/approle/role/jenkins/role-id)
export SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/jenkins/secret-id)

echo "Login with RoleID & SecretID"
export APP_TOKEN=$(vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")

VAULT_TOKEN=$APP_TOKEN vault kv get secret/mysql/webapp

VAULT_TOKEN=$APP_TOKEN vault kv get -format=json secret/mysql/webapp | jq -r .data.data.db_name > db_name.txt
VAULT_TOKEN=$APP_TOKEN vault kv get -format=json secret/mysql/webapp | jq -r .data.data.password > password.txt
VAULT_TOKEN=$APP_TOKEN vault kv get -format=json secret/mysql/webapp | jq -r .data.data.username > username.txt

gsutil cp *.txt gs://$DEVSHELL_PROJECT_ID

# echo "====================================="
# echo "               OPTIONAL              "
# echo "====================================="

# vault policy write base -<<EOF
# path "secret/data/training_*" {
#   capabilities = [ "create", "read" ]
# }
# EOF

# vault policy write test -<<EOF
# path "secret/data/test" {
#   capabilities = [ "create", "read", "update", "delete" ]
# }
# EOF

# vault policy write team-qa -<<EOF
# path "secret/data/team-qa" {
#   capabilities = [ "create", "read", "update", "delete" ]
# }
# EOF

# # vault auth enable userpass || true
# vault auth enable -path=userpass-test userpass

# vault write auth/userpass-test/users/bob \
#     password="training" \
#     policies="test"

# vault auth enable -path=userpass-qa userpass
# vault write auth/userpass-qa/users/bsmith \
#     password="training" \
#     policies="team-qa"


# # Create an Entity
# echo "Create an Entity for bob-smith"
# ENTITY_ID=$(vault write -format=json identity/entity name="bob-smith" policies="base" | jq -r ".data.id")

# echo "Get Accessor for userpass-test"
# TEST_ACCESSOR=$(vault auth list -format=json | jq -r '."userpass-test/".accessor')

# echo "Get Accessor for userpass-qa"
# QA_ACCESSOR=$(vault auth list -format=json | jq -r '."userpass-qa/".accessor')

# echo "Test Accessor: $TEST_ACCESSOR"
# echo "QA Accessor: $QA_ACCESSOR"

# vault write identity/entity-alias name="bob" \
#     canonical_id="$ENTITY_ID" \
#     mount_accessor="$TEST_ACCESSOR"

# vault write identity/entity-alias name="bsmith" \
#     canonical_id="$ENTITY_ID" \
#     mount_accessor="$QA_ACCESSOR"

# echo "Test the Entity "
# vault login -method=userpass -path=userpass-test \
#     username=bob password=training

# TBD

echo "Job is Done!"