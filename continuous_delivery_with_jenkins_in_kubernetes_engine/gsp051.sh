#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                 Task 1. Download the source code"
echo "======================================================================"
gsutil cp gs://spls/gsp051/continuous-deployment-on-kubernetes.zip .
unzip continuous-deployment-on-kubernetes.zip
cd continuous-deployment-on-kubernetes


echo "======================================================================"
echo "                     Task 2. Provision Jenkins"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                     Create a Kubernetes cluster"
echo "----------------------------------------------------------------------"
gcloud container clusters create jenkins-cd \
    --num-nodes=2 \
    --machine-type=e2-standard-2 \
    --scopes="https://www.googleapis.com/auth/source.read_write,cloud-platform"

echo "----------------------------------------------------------------------"
echo "                       Credential your cluster"
echo "----------------------------------------------------------------------"
gcloud container clusters get-credentials jenkins-cd


echo "======================================================================"
echo "                        Task 3. Set up Helm"
echo "======================================================================"
helm repo add jenkins https://charts.jenkins.io
helm repo update


echo "======================================================================"
echo "                    Task 4. Install and configure Jenkins"
echo "======================================================================"
helm install cd jenkins/jenkins -f jenkins/values.yaml --wait

kubectl create clusterrolebinding jenkins-deploy --clusterrole=cluster-admin --serviceaccount=default:cd-jenkins

export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/component=jenkins-master" -l "app.kubernetes.io/instance=cd" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:8080 >> /dev/null &


echo "======================================================================"
echo "                      Task 5. Connect to Jenkins"
echo "======================================================================"
export PASSWORD=$(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode)
echo "The PASSWORD is $PASSWORD"
# printf $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo


echo "======================================================================"
echo "                      Task 7. Deploy the application"
echo "======================================================================"

cd sample-app

kubectl create ns production

kubectl apply -f k8s/production -n production
kubectl apply -f k8s/canary -n production
kubectl apply -f k8s/services -n production

kubectl scale deployment gceme-frontend-production -n production --replicas 4

# kubectl get pods -n production -l app=gceme -l role=frontend
# kubectl get pods -n production -l app=gceme -l role=backend
# kubectl get service gceme-frontend -n production

export FRONTEND_SERVICE_IP=$(kubectl get -o jsonpath="{.status.loadBalancer.ingress[0].ip}" \
    --namespace=production services gceme-frontend)


echo "======================================================================"
echo "                  Task 8. Create the Jenkins pipeline"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "         Create a repository to host the sample app source code"
echo "----------------------------------------------------------------------"
curl -sS https://webi.sh/gh | sh
gh auth login
gh api user -q ".login"
GITHUB_USERNAME=$(gh api user -q ".login")
git config --global user.name "${GITHUB_USERNAME}"
git config --global user.email "${USER_EMAIL}"
echo ${GITHUB_USERNAME}
echo ${USER_EMAIL}


gh repo create default --private
git init
git config credential.helper gcloud.sh
git remote add origin https://github.com/${GITHUB_USERNAME}/default
git add .
git commit -m "Initial commit"
git push origin master