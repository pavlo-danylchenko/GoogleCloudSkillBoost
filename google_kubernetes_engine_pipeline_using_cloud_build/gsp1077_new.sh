#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                     Task 1. Initialize your lab"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                Set PROJECT_ID and PROJECT_NUMBER"
echo "----------------------------------------------------------------------"
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export GIT_SERVER_IP=$(gcloud compute instances describe git-server \
    --zone= --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Git Server IP is: ${GIT_SERVER_IP}"

echo "----------------------------------------------------------------------"
echo "Enable the APIs for GKE, Cloud Build, Secret Manager and Artifact Analysis"
echo "----------------------------------------------------------------------"
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com

echo "----------------------------------------------------------------------"
echo "            Create an Artifact Registry Docker repository"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$REGION

echo "----------------------------------------------------------------------"
echo "   Create a GKE cluster to deploy the sample application"
echo "----------------------------------------------------------------------"
gcloud container clusters create hello-cloudbuild \
    --num-nodes=1 \
    --location=$REGION

echo "----------------------------------------------------------------------"
echo "              Configure Git and GitHub in Cloud Shell"
echo "----------------------------------------------------------------------"
git config --global user.name "giteaadmin"
git config --global user.email "student@qwiklabs.net"


echo "======================================================================"
echo "     Task 2. Connect to the Git repositories on the Git server"
echo "======================================================================"
cd ~
mkdir hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app

cd ~/hello-cloudbuild-app
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl
git init
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git
git branch -m main
git add . && git commit -m "initial commit"
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main


echo "======================================================================"
echo "          Task 3. Create a container image with Cloud Build"
echo "======================================================================"
cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .


echo "======================================================================"
echo "    Task 4. Create and run the Continuous Integration (CI) pipeline"
echo "======================================================================"
cd ~/hello-cloudbuild-app
git add .
git commit -m "Trigger CI pipeline"
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main

gcloud builds submit --config=cloudbuild.yaml --substitutions=SHORT_SHA=$(git rev-parse --short=7 HEAD) .


echo "======================================================================"
echo "          Task 5. Store the SSH key secret in Secret Manager"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "            Create an SSH key and store it in Secret Manager"
echo "----------------------------------------------------------------------"
mkdir -p ~/workingdir && cd ~/workingdir
ssh-keygen -t rsa -b 4096 -N '' -f id_rsa -C "student@qwiklabs.net"

gcloud secrets create ssh_key_secret --data-file=$HOME/workingdir/id_rsa

echo "----------------------------------------------------------------------"
echo "    Grant the service account permission to access Secret Manager"
echo "----------------------------------------------------------------------"
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
  --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor


echo "======================================================================"
echo "         Task 6. Create the test environment and CD pipeline"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                  Grant Cloud Build access to GKE"
echo "----------------------------------------------------------------------"
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
  --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role=roles/container.developer


mkdir ~/hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* ~/hello-cloudbuild-env
cd ~/hello-cloudbuild-env
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

cd ~/hello-cloudbuild-env
git init
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git
git branch -m main
git add . && git commit -m "initial commit"
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git main


cd ~/hello-cloudbuild-env
git checkout -b production
git checkout -b candidate
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git production
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate


cd ~/hello-cloudbuild-env
cat <<'EOF' > cloudbuild.yaml
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

substitutions:
  _COMMIT_SHA: 'v1.0'

steps:
# This step deploys the new version of our container image
# in the hello-cloudbuild Kubernetes Engine cluster.
- name: 'gcr.io/cloud-builders/kubectl'
  id: Deploy
  args:
  - 'apply'
  - '-f'
  - 'kubernetes.yaml'
  env:
  - 'CLOUDSDK_COMPUTE_REGION='
  - 'CLOUDSDK_CONTAINER_CLUSTER=hello-cloudbuild'

# This step copies the applied manifest to the production branch
- name: 'gcr.io/cloud-builders/gcloud'
  id: Copy to production branch
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    git clone -b production http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git prod_repo && \
    cd prod_repo && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build" && \
    cp ../kubernetes.yaml kubernetes.yaml && \
    git add kubernetes.yaml && \
    git commit -m "Deployed manifest from commit $_COMMIT_SHA" && \
    git push origin production

options:
  logging: CLOUD_LOGGING_ONLY
EOF
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml

cd ~/hello-cloudbuild-env
git checkout candidate
git add cloudbuild.yaml
git commit -m "Create cloudbuild.yaml for deployment"
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate


echo "----------------------------------------------------------------------"
echo "Modify the continuous integration pipeline to trigger the continuous delivery pipeline"
echo "----------------------------------------------------------------------"
cd ~/hello-cloudbuild-app
cat <<'EOF' > cloudbuild.yaml
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

substitutions:
  _SHORT_SHA: 'v1.0'
  _COMMIT_SHA: 'v1.0'

steps:
# This step runs the unit tests on the app
- name: 'python:3.7-slim'
  id: Test
  entrypoint: /bin/sh
  args:
  - -c
  - 'pip install flask && python test_app.py -v'

# This step builds the container image.
- name: 'gcr.io/cloud-builders/docker'
  id: Build
  args:
  - 'build'
  - '-t'
  - '-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'
  - '.'

# This step pushes the image to Artifact Registry
- name: 'gcr.io/cloud-builders/docker'
  id: Push
  args:
  - 'push'
  - '-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'

# This step clones the hello-cloudbuild-env repository
- name: 'gcr.io/cloud-builders/gcloud'
  id: Clone env repo
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    git clone http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git && \
    cd hello-cloudbuild-env && \
    git checkout candidate && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build"

# This step generates the new manifest
- name: 'gcr.io/cloud-builders/gcloud'
  id: Generate manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
     sed "s/GOOGLE_CLOUD_PROJECT/${PROJECT_ID}/g" kubernetes.yaml.tpl | \
     sed "s/COMMIT_SHA/${_SHORT_SHA}/g" > hello-cloudbuild-env/kubernetes.yaml

# This step pushes the manifest back to hello-cloudbuild-env candidate branch
- name: 'gcr.io/cloud-builders/gcloud'
  id: Push manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    cd hello-cloudbuild-env && \
    git add kubernetes.yaml && \
    git commit -m "Deploying image -docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:${_SHORT_SHA}
    Built from commit ${_COMMIT_SHA} of repository hello-cloudbuild-app
    Author: $(git log --format='%an <%ae>' -n 1 HEAD)" && \
    git push origin candidate

options:
  logging: CLOUD_LOGGING_ONLY
EOF
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml

cd ~/hello-cloudbuild-app
git add cloudbuild.yaml
git commit -m "Trigger CD pipeline"
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
gcloud builds submit --config=cloudbuild.yaml --substitutions=_SHORT_SHA=$(git rev-parse --short=7 HEAD),_COMMIT_SHA=$(git rev-parse HEAD) .


cd ~/hello-cloudbuild-env
git pull http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
gcloud builds submit --config=cloudbuild.yaml --substitutions=_COMMIT_SHA=$(git rev-parse HEAD) .

echo "======================================================================"
echo "                           JOB is DONE !!!"
echo "======================================================================"