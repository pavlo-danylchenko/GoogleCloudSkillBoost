#!/bin/bash
set -euo pipefail

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")
gcloud config set project $DEVSHELL_PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo "======================================================================"
echo "                     Task 1. Clone the sample code"
echo "======================================================================"
cat > server.js << EOF
var http = require('http');
var handleRequest = function(request, response) {
  response.writeHead(200);
  response.end("Hello World!");
}
var www = http.createServer(handleRequest);
www.listen(8080);
EOF

node server.js &
PROCESS_ID=$!
sleep 5
curl http://localhost:8080
kill $PROCESS_ID

echo "======================================================================"
echo "                   Task 2. Create a Docker container image"
echo "======================================================================"
cat > Dockerfile << EOF
FROM node:6.9.2
EXPOSE 8080
COPY server.js .
CMD ["node", "server.js"]
EOF

docker build -t hello-node:v1 .
docker run -d -p 8080:8080 hello-node:v1
sleep 5
echo "----------------------------------------------------------------------"
echo "                        To see your results"
echo "----------------------------------------------------------------------"
curl -s http://localhost:8080
docker stop $(docker ps -lq)
# docker stop $(docker ps -q --filter ancestor=hello-node:v1)

echo "----------------------------------------------------------------------"
echo "              Creating a repository in Artifact Registry"
echo "----------------------------------------------------------------------"
gcloud artifacts repositories create my-docker-repo \
    --repository-format=docker \
    --location=$REGION \
    --project=$DEVSHELL_PROJECT_ID

echo "----------------------------------------------------------------------"
echo "                  Configure docker authentication"
echo "----------------------------------------------------------------------"
gcloud auth configure-docker --quiet

echo "----------------------------------------------------------------------"
echo "                  Tag image with the repository name"
echo "----------------------------------------------------------------------"
docker tag hello-node:v1 $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/my-docker-repo/hello-node:v1

echo "----------------------------------------------------------------------"
echo "                 Push container image to the repository"
echo "----------------------------------------------------------------------"
docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/my-docker-repo/hello-node:v1


echo "======================================================================"
echo "                      Task 3. Create your cluster"
echo "======================================================================"
gcloud container clusters create hello-world \
    --num-nodes=2 \
    --machine-type=e2-medium \
    --zone=$ZONE

echo "======================================================================"
echo "                      Task 4. Create your pod"
echo "======================================================================"
kubectl create deployment hello-node \
    --image=$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/my-docker-repo/hello-node:v1

echo "----------------------------------------------------------------------"
echo "                       View the deployment"
echo "----------------------------------------------------------------------"
kudectl get deployments

echo "----------------------------------------------------------------------"
echo "                 View the pod created by the deployment"
echo "----------------------------------------------------------------------"
kubectl get pods

echo "----------------------------------------------------------------------"
echo "                     kubectl cluster-info"
echo "----------------------------------------------------------------------"
kubectl cluster-info

echo "----------------------------------------------------------------------"
echo "                     kubectl config view"
echo "----------------------------------------------------------------------"
kubectl config view

echo "----------------------------------------------------------------------"
echo "                     kubectl get events"
echo "----------------------------------------------------------------------"
kubectl get events


echo "======================================================================"
echo "                      Task 5. Allow external traffic"
echo "======================================================================"
kubectl expose deployment hello-node --type=LoadBalancer --port=8080

echo "----------------------------------------------------------------------"
echo "                     kubectl get services"
echo "----------------------------------------------------------------------"
kubectl get services


echo "======================================================================"
echo "                      Task 6. Scale up your service"
echo "======================================================================"
kubectl scale deployment hello-node --replicas=4

echo "----------------------------------------------------------------------"
echo "             Request a description of the updated deployment"
echo "----------------------------------------------------------------------"
kubectl get deployment

echo "----------------------------------------------------------------------"
echo "                        List all the pods"
echo "----------------------------------------------------------------------"
kubectl get pods


echo "======================================================================"
echo "                Task 7. Roll out an upgrade to your service"
echo "======================================================================"
sed -i "s/Hello World/Hello Kubernetes World!/g" server.js
docker build -t hello-node:v2 .
docker tag hello-node:v2 $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/my-docker-repo/hello-node:v2
docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/my-docker-repo/hello-node:v2

# kubectl edit deployment hello-node
# kubectl get deployments
echo "Job is Done!"