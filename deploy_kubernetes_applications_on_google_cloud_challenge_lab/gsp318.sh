#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

read -p "Input Repository Name: " REPO_NAME
read -p "Input IMAGE_NAME: " IMAGE_NAME
read -p "Input TAG_NAME: " TAG_NAME

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "        Task 1. Create a Docker image and store the Dockerfile"
echo "======================================================================"
source <(gsutil cat gs://spls/gsp318/script.sh)
gsutil cp gs://spls/gsp318/valkyrie-app.tgz .
tar -xzf valkyrie-app.tgz
cd valkyrie-app


cat > Dockerfile << EOF
FROM golang:1.10
WORKDIR /go/src/app
COPY source .
RUN go install -v
ENTRYPOINT ["app","-single=true","-port=8080"]
EOF

docker build -t $IMAGE_NAME:$TAG_NAME .


echo "======================================================================"
echo "            Task 2. Test the created Docker image"
echo "======================================================================"
docker run -p 8080:8080 --name my-app -d $IMAGE_NAME:$TAG_NAME


echo "======================================================================"
echo "        Task 3. Push the Docker image to the Artifact Registry"
echo "======================================================================"
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Containers"

gcloud auth configure-docker $REGION-docker.pkg.dev
export IMAGE_PATH=$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$TAG_NAME

docker build -t $IMAGE_PATH .
docker push $IMAGE_PATH


echo "======================================================================"
echo "        Task 4. Create and expose a deployment in Kubernetes"
echo "======================================================================"
gcloud container clusters get-credentials valkyrie-dev --zone $ZONE

sed -i "s#IMAGE_HERE#$IMAGE_PATH#g" k8s/deployment.yaml

kubectl create -f k8s/deployment.yaml
kubectl create -f k8s/service.yaml


echo "======================================================================"
echo "                     JOB is DONE !!!"
echo "======================================================================"