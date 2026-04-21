Prepare the Quiz application
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
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                  Prepare the Quiz application"
echo "======================================================================"
git clone https://github.com/GoogleCloudPlatform/training-data-analyst
ln -s ~/training-data-analyst/courses/developingapps/v1.2/python/kubernetesengine ~/kubernetesengine

cd ~/kubernetesengine/start

export REGION=$REGION
sed -i -e 's/us-central1/'"$REGION"'/g' -e 's/python3/'"python3.12"'/g' prepare_environment.sh

. prepare_environment.sh

echo "======================================================================"
echo "            Create and connect to a Kubernetes Engine cluster"
echo "======================================================================"

gcloud container clusters create quiz-cluster \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --scopes=https://www.googleapis.com/auth/cloud-platform

gcloud container clusters get-credentials quiz-cluster --zone=$ZONE --project=$DEVSHELL_PROJECT_ID

kubectl get pods

echo "======================================================================"
echo "            Create a Docker Repository on Artifact registry"
echo "======================================================================"
gcloud artifacts repositories create container-dev-repo \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Container Dev Workshop"


echo "======================================================================"
echo "               Build Docker images using Cloud Build"
echo "======================================================================"

cat > frontend/Dockerfile << EOF
FROM gcr.io/google_appengine/python

RUN virtualenv -p python3.7 /env

ENV VIRTUAL_ENV /env
ENV PATH /env/bin:$PATH

ADD requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

ADD . /app

CMD gunicorn -b 0.0.0.0:$PORT quiz:app
EOF


cat > backend/Dockerfile << EOF
FROM gcr.io/google_appengine/python

RUN virtualenv -p python3.7 /env

ENV VIRTUAL_ENV /env
ENV PATH /env/bin:$PATH

ADD requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

ADD . /app

CMD python -m quiz.console.worker
EOF

cd ~/kubernetesengine/start
gcloud builds submit -t $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/container-dev-repo/quiz-frontend:v1 ./frontend/

gcloud builds submit -t $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/container-dev-repo/quiz-backend:v1 ./backend/


echo "======================================================================"
echo "         Create a Kubernetes deployment and service resources"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "               Create a Kubernetes deployment file"
echo "----------------------------------------------------------------------"
sed -i -e "s/[GCLOUD_PROJECT]/$DEVSHELL_PROJECT_ID/g" \
    -e "s/[GCLOUD_BUCKET]/$GCLOUD_BUCKET/g" \
    -e "s/[FRONTEND_IMAGE_IDENTIFIER]/$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/container-dev-repo/quiz-frontend:v1/g" \
    frontend-deployment.yaml


sed -i -e "s/[GCLOUD_PROJECT]/$DEVSHELL_PROJECT_ID/g" \
    -e "s/[GCLOUD_BUCKET]/$GCLOUD_BUCKET/g" \
    -e "s/[BACKEND_IMAGE_IDENTIFIER]/$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/container-dev-repo/quiz-backend:v1/g" \
    backend-deployment.yaml


echo "----------------------------------------------------------------------"
echo "              Execute the deployment and service files"
echo "----------------------------------------------------------------------"
kubectl create -f ./frontend-deployment.yaml
kubectl create -f ./backend-deployment.yaml
kubectl create -f ./frontend-service.yaml

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"