#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $REGION
echo $ZONE

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud services enable networkconnectivity.googleapis.com


echo "======================================================================"
echo "                     Task 1. Create a hub"
echo "======================================================================"
gcloud network-connectivity hubs create ncc-hub


echo "======================================================================"
echo "                Task 2. Configure VPCs as NCC spokes"
echo "======================================================================"
gcloud config set accessibility/screen_reader false
gcloud compute networks subnets list --network=vpc1-ncc

gcloud network-connectivity spokes linked-vpc-network create vpc1-spoke1 \
    --hub=ncc-hub \
    --vpc-network=vpc1-ncc \
    --exclude-export-ranges=10.1.2.0/24 \
    --global

gcloud network-connectivity spokes linked-vpc-network create vpc2-spoke2 \
    --hub=ncc-hub \
    --vpc-network=vpc2-ncc \
    --exclude-export-ranges=10.3.3.0/24 \
    --global


echo "======================================================================"
echo "              Task 3. Verify IPv4 Data Path Connectivity"
echo "======================================================================"


echo "======================================================================"
echo "              Task 4. Set up Private Service Connect"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Reserve an internal IP address"
echo "----------------------------------------------------------------------"
export SUBNET_CIDR=$(gcloud compute networks subnets describe vpc2-ncc-subnet1 \
    --region=$REGION \
    --project=$DEVSHELL_PROJECT_ID \
    --format="value(ipCidrRange)")

export IP_ADDRESS=${SUBNET_CIDR%.*}.17

gcloud compute addresses create cloudsql-psc \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION \
    --subnet=vpc2-ncc-subnet1 \
    --addresses=$IP_ADDRESS

echo "----------------------------------------------------------------------"
echo "                     Get the service attachment URI"
echo "----------------------------------------------------------------------"
export SQL_INSTANCE=$(gcloud sql instances list \
    --format="value(name)" | head -n 1)

echo $SQL_INSTANCE

export SERVICE_ATTACHMENT_URI=$(gcloud sql instances describe $SQL_INSTANCE \
    --project=$DEVSHELL_PROJECT_ID \
    --format="value(pscServiceAttachmentLink)")

echo "----------------------------------------------------------------------"
echo "                   Create the Private Service Connect"
echo "----------------------------------------------------------------------"
gcloud compute forwarding-rules create cloudsql-psc-ep \
    --address=cloudsql-psc \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION \
    --network=vpc2-ncc  \
    --target-service-attachment=$SERVICE_ATTACHMENT_URI \
    --allow-psc-global-access

echo "----------------------------------------------------------------------"
echo "                      Configure a DNS managed zone"
echo "----------------------------------------------------------------------"
gcloud dns managed-zones create cloudsql-dns \
    --project=$DEVSHELL_PROJECT_ID \
    --description="DNS zone for the Cloud SQL instances" \
    --dns-name=$REGION.sql.goog. \
    --networks=vpc2-ncc  \
    --visibility=private

echo "----------------------------------------------------------------------"
echo "            Add a DNS record for the Private Service Connect"
echo "----------------------------------------------------------------------"
export DNS_NAME=$(gcloud sql instances describe $SQL_INSTANCE \
    --project=$DEVSHELL_PROJECT_ID \
    --format="value(dnsName)")

gcloud dns record-sets create $DNS_NAME \
    --project=$DEVSHELL_PROJECT_ID \
    --type=A \
    --rrdatas=$IP_ADDRESS \
    --zone=cloudsql-dns

echo "======================================================================"
echo "        Task 5. Connect to Cloud SQL via Private Service Connect"
echo "======================================================================"
cat > /tmp/company.sql <<'SQL'
CREATE DATABASE company;

\l

\c company

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    first VARCHAR(255) NOT NULL,
    last VARCHAR(255) NOT NULL,
    salary DECIMAL (10, 2)
);

INSERT INTO employees (first, last, salary) VALUES
    ('Max', 'Mustermann', 5000.00),
    ('Anna', 'Schmidt', 7000.00),
    ('Peter', 'Mayer', 6000.00);

SELECT * FROM employees;
SQL

gcloud compute instances add-metadata cloudsql-client \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=enable-oslogin=false

gcloud compute scp /tmp/company.sql cloudsql-client:/tmp/company.sql \
    --zone=$ZONE \
    --tunnel-through-iap \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet

gcloud compute ssh cloudsql-client \
    --zone=$ZONE \
    --tunnel-through-iap \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet \
    --command="
        PGPASSWORD='changeme' \
        psql 'sslmode=disable dbname=postgres user=postgres host=$DNS_NAME' \
        -f /tmp/company.sql
    "


echo "======================================================================"
echo "                 Task 6. Delete resources (OPTIONAL)"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                       Delete spokes and hub"
echo "----------------------------------------------------------------------"


echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"