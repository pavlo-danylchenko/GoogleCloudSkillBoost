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
echo "                Task 1. Clone the source repository"
echo "======================================================================"
cd ~
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

echo "======================================================================"
echo "                   Task 2. Create a GKE cluster"
echo "======================================================================"
gcloud services enable container.googleapis.com
gcloud container clusters create fancy-cluster --num-nodes=3 \
    --machine-type=e2-standard-4


echo "======================================================================"
echo "                 Task 3. Deploy the existing monolith"
echo "======================================================================"
cd ~/monolith-to-microservices
./deploy-monolith.sh
sleep 20

EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  echo "Waiting for the IP for monolith..."
  export MONOLITH_IP=$(kubectl get svc monolith \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$MONOLITH_IP" ] && sleep 5
done

echo "External IP is: $MONOLITH_IP"

curl -s "http://$MONOLITH_IP"


echo "======================================================================"
echo "                 Task 4. Migrate orders to a microservice"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                       Create Orders microservice"
echo "----------------------------------------------------------------------"

echo "----------------------------------------------------------------------"
echo "               Create a Docker container with Cloud Build"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/microservices/src/orders
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/orders:1.0.0 .

echo "----------------------------------------------------------------------"
echo "                       Deploy container to GKE"
echo "----------------------------------------------------------------------"
kubectl create deployment orders --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/orders:1.0.0

echo "----------------------------------------------------------------------"
echo "                         Expose GKE container"
echo "----------------------------------------------------------------------"
kubectl expose deployment orders --type=LoadBalancer --port 80 --target-port 8081
sleep 20

export ORDERS_IP=$(kubectl get svc orders -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Orders microservice is available at http://$ORDERS_IP"
curl -s "http://$ORDERS_IP"


echo "----------------------------------------------------------------------"
echo "                         Reconfigure the monolith"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/react-app

cat > .env.monolith << EOF
REACT_APP_ORDERS_URL=http://$ORDERS_IP/api/orders
REACT_APP_PRODUCTS_URL=/service/products
EOF

npm run build:monolith

cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:2.0.0 .
kubectl set image deployment/monolith monolith=gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:2.0.0


echo "======================================================================"
echo "                 Task 5. Migrate Products to microservice"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                      Create new Products microservice"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/microservices/src/products
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/products:1.0.0 .

kubectl create deployment products --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/products:1.0.0

kubectl expose deployment products --type=LoadBalancer --port=80 ---target-port=8082
sleep 20
export PRODUCTS_IP=$(kubectl get svc products -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "PRODUCTS microservice is available at http://$PRODUCTS_IP"
curl -s "http://$PRODUCTS_IP"


echo "----------------------------------------------------------------------"
echo "                      Reconfigure the monolith"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/react-app

cat > .env.monolith << EOF
REACT_APP_ORDERS_URL=http://$ORDERS_IP/api/orders
REACT_APP_PRODUCTS_URL=http://$PRODUCTS_IP/api/products
EOF

npm run build:monolith

cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:3.0.0 .
kubectl set image deployment/monolith monolith=gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:3.0.0


echo "======================================================================"
echo "                 Task 6. Migrate Frontend to microservice"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                   Create a new frontend microservice"
echo "----------------------------------------------------------------------"
cd ~/monolith-to-microservices/react-app
cp .env.monolith .env
npm run build

cd ~/monolith-to-microservices/microservices/src/frontend
gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/frontend:1.0.0 .

kubectl create deployment frontend --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/frontend:1.0.0

kubectl expose deployment frontend --type=LoadBalancer --port=80 --target-port=8080

echo "----------------------------------------------------------------------"
echo "                        Delete the monolith"
echo "----------------------------------------------------------------------"
kubectl delete deployment monolith
kubectl delete service monolith

echo "----------------------------------------------------------------------"
echo "                        Test your work"
echo "----------------------------------------------------------------------"
kubectl get svc

echo "======================================================================"
echo "                       JOB is DONE !!!"
echo "======================================================================"