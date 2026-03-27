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

echo "======================================================================"
echo "                  Task 1. Key Generation and Encryption"
echo "======================================================================"
export MPC_PROJECT_ID=$(gcloud config get-value core/project)

gcloud services enable cloudkms.googleapis.com \
    compute.googleapis.com \
    confidentialcomputing.googleapis.com \
    iamcredentials.googleapis.com \
    artifactregistry.googleapis.com

echo "----------------------------------------------------------------------"
echo "        Create the encryption keyring in KMS for the private key"
echo "----------------------------------------------------------------------"
gcloud kms keyrings create mpc-keys --location=global

gcloud kms keys create mpc-key --location=global \
  --keyring=mpc-keys --purpose=encryption --protection-level=hsm

gcloud kms keys add-iam-policy-binding \
  projects/$MPC_PROJECT_ID/locations/global/keyRings/mpc-keys/cryptoKeys/mpc-key \
  --member="user:$(gcloud config get-value account)" \
  --role='roles/cloudkms.cryptoKeyEncrypter'


echo "----------------------------------------------------------------------"
echo "                Create the Ethereum private key"
echo "----------------------------------------------------------------------"
echo -n "00000000000000000000000000000000" >> alice-key-share
echo -n "00000000000000000000000000000001" >> bob-key-share


echo "----------------------------------------------------------------------"
echo "           Encrypt the Ethereum private key shards using KMS"
echo "----------------------------------------------------------------------"
gcloud kms encrypt \
    --key mpc-key \
    --keyring mpc-keys \
    --location global  \
    --plaintext-file alice-key-share \
    --ciphertext-file alice-encrypted-key-share

gcloud kms encrypt \
    --key mpc-key \
    --keyring mpc-keys \
    --location global  \
    --plaintext-file bob-key-share \
    --ciphertext-file bob-encrypted-key-share

echo "----------------------------------------------------------------------"
echo "            Create the bucket to store the encrypted keys"
echo "----------------------------------------------------------------------"
# gsutil mb gs://$MPC_PROJECT_ID-mpc-encrypted-keys --location=$REGION
gcloud storage buckets create gs://$MPC_PROJECT_ID-mpc-encrypted-keys --location=$REGION

gcloud storage cp alice-encrypted-key-share gs://$MPC_PROJECT_ID-mpc-encrypted-keys/
gcloud storage cp bob-encrypted-key-share gs://$MPC_PROJECT_ID-mpc-encrypted-keys/


echo "======================================================================"
echo "            Task 2. Service Account and Workload Identity Pool"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                  Create the MPC Service Account"
echo "----------------------------------------------------------------------"
gcloud iam service-accounts create trusted-mpc-account

gcloud kms keys add-iam-policy-binding mpc-key \
--keyring='mpc-keys' --location='global' \
--member="serviceAccount:trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com" \
--role='roles/cloudkms.cryptoKeyDecrypter'


echo "----------------------------------------------------------------------"
echo "                  Create a Workload Identity Pool"
echo "----------------------------------------------------------------------"
gcloud iam workload-identity-pools create trusted-workload-pool --location="global"

gcloud iam workload-identity-pools providers create-oidc attestation-verifier \
  --location="global" \
  --workload-identity-pool="trusted-workload-pool" \
  --issuer-uri="https://confidentialcomputing.googleapis.com/" \
  --allowed-audiences="https://sts.googleapis.com" \
  --attribute-mapping="google.subject='assertion.sub'" \
  --attribute-condition="assertion.swname == 'CONFIDENTIAL_SPACE' &&
    'STABLE' in assertion.submods.confidential_space.support_attributes &&
    assertion.submods.container.image_reference ==
    '$REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest'
    && 'run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com' in
    assertion.google_service_accounts"


gcloud iam service-accounts add-iam-policy-binding \
    trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $MPC_PROJECT_ID \
        --format="value(projectNumber)")/locations/global/workloadIdentityPools/trusted-workload-pool/*"


echo "----------------------------------------------------------------------"
echo "               Create run-confidential-vm service account"
echo "----------------------------------------------------------------------"
gcloud iam service-accounts create run-confidential-vm

gcloud iam service-accounts add-iam-policy-binding \
  run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
  --member="user:$(gcloud config get-value account)" \
  --role='roles/iam.serviceAccountUser'

gcloud projects add-iam-policy-binding $MPC_PROJECT_ID \
  --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
  --role='roles/logging.logWriter'



echo "======================================================================"
echo "         Task 3. Create the Blockchain Node and Results Bucket"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                      Ganache Ethereum Node"
echo "----------------------------------------------------------------------"
gcloud compute instances create-with-container mpc-lab-ethereum-node  \
  --zone=ZONE \
  --tags=http-server \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --container-image=docker.io/trufflesuite/ganache:v7.7.3 \
  --container-arg=--wallet.accounts=\"0x0000000000000000000000000000000000000000000000000000000000000001,0x21E19E0C9BAB2400000\" \
  --container-arg=--port=80 \
  --machine-type=e2-medium


echo "----------------------------------------------------------------------"
echo "                      Create a bucket for results"
echo "----------------------------------------------------------------------"
gcloud storage buckets create gs://$MPC_PROJECT_ID-mpc-results-storage \
    --location=$REGION

gsutil iam ch \
  serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com:objectCreator \
  gs://$MPC_PROJECT_ID-mpc-results-storage

gsutil iam ch \
  serviceAccount:trusted-mpc-account@$MPC_PROJECT_ID.iam.gserviceaccount.com:objectViewer \
  gs://$MPC_PROJECT_ID-mpc-encrypted-keys



echo "======================================================================"
echo "                 Task 4. Create the MPC Instance"
echo "======================================================================"
mkdir mpc-ethereum-demo && cd $_

cat > package.json << EOF
{
  "name": "gcp-mpc-ethereum-demo",
  "version": "1.0.0",
  "description": "Demo for GCP multi-party-compute on Confidential Space",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "type": "module",
  "dependencies": {
    "@google-cloud/kms": "^3.2.0",
    "@google-cloud/storage": "^6.9.2",
    "ethers": "^5.7.2",
    "fast-crc32c": "^2.0.0"
  },
  "author": "",
  "license": "ISC"
}
EOF

cat > index.js << EOF
import {signTransaction, submitTransaction, uploadFromMemory} from './mpc.js';

const signAndSubmitTransaction = async () => {
  try {
    // Create the unsigned transaction object
    const unsignedTransaction = {
      nonce: 0,
      gasLimit: 21000,
      gasPrice: '0x09184e72a000',
      to: '0x0000000000000000000000000000000000000000',
      value: '0x00',
      data: '0x',
    };

    // Sign the transaction
    const signedTransaction = await signTransaction(unsignedTransaction);

    // Submit the transaction to Ganache
    const transaction = await submitTransaction(signedTransaction);

    // Write the transaction receipt
    uploadFromMemory(transaction);

    return transaction;
  } catch (e) {
    console.log(e);
    uploadFromMemory(e);
  }
};

await signAndSubmitTransaction();
EOF

cat > mpc.js << EOF
import {ethers} from 'ethers';
import {decryptSymmetric} from './kms-decrypt.js';
import {Storage} from '@google-cloud/storage';
import {credentialConfig} from './credential-config.js';

const providers = ethers.providers;
const Wallet = ethers.Wallet;

// The ID of the GCS bucket holding the encrypted keys
const bucketName = process.env.KEY_BUCKET;

// Name of the encrypted key files.
const encryptedKeyFile1 = 'alice-encrypted-key-share';
const encryptedKeyFile2 = 'bob-encrypted-key-share';

// Create a new storage client with the credentials
const storageWithCreds = new Storage({
  credentials: credentialConfig,
});

// Create a new storage client without the credentials
const storage = new Storage();

const downloadIntoMemory = async (keyFile) => {
  // Downloads the file into a buffer in memory.
  const contents = await storageWithCreds.bucket(bucketName).file(keyFile).download();

  return contents;
};

const provider = new providers.JsonRpcProvider(`http://${process.env.NODE_URL}:80`);

export const signTransaction = async (unsignedTransaction) => {
  /* Check if Alice and Bob have both approved the transaction
  For this example, we're checking if their encrypted keys are available. */
  const encryptedKey1 = await downloadIntoMemory(encryptedKeyFile1).catch(console.error);
  const encryptedKey2 = await downloadIntoMemory(encryptedKeyFile2).catch(console.error);

  // For each key share, make a call to KMS to decrypt the key
  const privateKeyshare1 = await decryptSymmetric(encryptedKey1[0]);
  const privateKeyshare2 = await decryptSymmetric(encryptedKey2[0]);

  /* Perform the MPC calculations
  In this example, we're combining the private key shares
  Alternatively, you could import your mpc calculations here */
  const wallet = new Wallet(privateKeyshare1 + privateKeyshare2);

  // Sign the transaction
  const signedTransaction = await wallet.signTransaction(unsignedTransaction);

  return signedTransaction;
};

export const submitTransaction = async (signedTransaction) => {
  // This can now be sent to Ganache
  const hash = await provider.sendTransaction(signedTransaction);
  return hash;
};

export const uploadFromMemory = async (contents) => {
  // Upload the results to the bucket without service account impersonation
  await storage.bucket(process.env.RESULTS_BUCKET)
      .file('transaction_receipt_' + Date.now())
      .save(JSON.stringify(contents));
};
EOF

cat > kms-decrypt.js << EOF
import {KeyManagementServiceClient} from '@google-cloud/kms';
import {credentialConfig} from './credential-config.js';

import crc32c from 'fast-crc32c';

const projectId = process.env.MPC_PROJECT_ID;
const locationId = 'global';
const keyRingId = 'mpc-keys';
const keyId = 'mpc-key';

// Instantiates a client
const client = new KeyManagementServiceClient({
  credentials: credentialConfig,
});

// Build the key name
const keyName = client.cryptoKeyPath(projectId, locationId, keyRingId, keyId);

export const decryptSymmetric = async (ciphertext) => {
  const ciphertextCrc32c = crc32c.calculate(ciphertext);
  const [decryptResponse] = await client.decrypt({
    name: keyName,
    ciphertext,
    ciphertextCrc32c: {
      value: ciphertextCrc32c,
    },
  });

  // Optional, but recommended: perform integrity verification on decryptResponse.
  // For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
  // https://cloud.google.com/kms/docs/data-integrity-guidelines
  if (
    crc32c.calculate(decryptResponse.plaintext) !==
    Number(decryptResponse.plaintextCrc32c.value)
  ) {
    throw new Error('Decrypt: response corrupted in-transit');
  }

  const plaintext = decryptResponse.plaintext.toString();

  return plaintext;
};
EOF


cat > credential-config.js << EOF
export const credentialConfig = {
  type: 'external_account',
  audience: `//iam.googleapis.com/projects/${process.env.MPC_PROJECT_NUMBER}/locations/global/workloadIdentityPools/trusted-workload-pool/providers/attestation-verifier`,
  subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
  token_url: 'https://sts.googleapis.com/v1/token',
  credential_source: {
    file: '/run/container_launcher/attestation_verifier_claims_token',
  },
  service_account_impersonation_url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/trusted-mpc-account@${process.env.MPC_PROJECT_ID}.iam.gserviceaccount.com:generateAccessToken`,
};
EOF

cat > Dockerfile << EOF
# pull official base image
FROM node:16.18.0

ENV NODE_ENV=production

WORKDIR /app

COPY ["package.json", "package-lock.json*", "./"]

RUN npm install --production

COPY . .

LABEL "tee.launch_policy.allow_cmd_override"="true"
LABEL "tee.launch_policy.allow_env_override"="NODE_URL,RESULTS_BUCKET,KEY_BUCKET,MPC_PROJECT_NUMBER,MPC_PROJECT_ID"

CMD [ "node", "index.js" ]
EOF


echo "----------------------------------------------------------------------"
echo "                        Create the repository"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create mpc-workloads \
  --repository-format=docker --location=$REGION

gcloud auth configure-docker $REGION-docker.pkg.dev

docker build -t $REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest mpc-ethereum-demo

docker push $REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest

gcloud artifacts repositories add-iam-policy-binding mpc-workloads \
    --location=$REGION \
    --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/artifactregistry.reader

gcloud projects add-iam-policy-binding $MPC_PROJECT_ID \
    --member=serviceAccount:run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/confidentialcomputing.workloadUser



echo "======================================================================"
echo "      Task 5. Create the MPC Operator Confidential Space Instance"
echo "======================================================================"

gcloud compute instances create mpc-cvm --confidential-compute \
  --shielded-secure-boot \
  --maintenance-policy=TERMINATE --scopes=cloud-platform  --zone=$ZONE \
  --image-project=confidential-space-images \
  --image-family=confidential-space \
  --service-account=run-confidential-vm@$MPC_PROJECT_ID.iam.gserviceaccount.com \
  --metadata ^~^tee-image-reference=$REGION-docker.pkg.dev/$MPC_PROJECT_ID/mpc-workloads/initial-workload-container:latest~tee-restart-policy=Never~tee-env-NODE_URL=$(gcloud compute instances describe mpc-lab-ethereum-node --format='get(networkInterfaces[0].networkIP)' --zone=$ZONE)~tee-env-RESULTS_BUCKET=$MPC_PROJECT_ID-mpc-results-storage~tee-env-KEY_BUCKET=$MPC_PROJECT_ID-mpc-encrypted-keys~tee-env-MPC_PROJECT_ID=$MPC_PROJECT_ID~tee-env-MPC_PROJECT_NUMBER=$(gcloud projects describe $MPC_PROJECT_ID --format="value(projectNumber)")


echo "======================================================================"
echo "                           JOB is DONE !"
echo "======================================================================"