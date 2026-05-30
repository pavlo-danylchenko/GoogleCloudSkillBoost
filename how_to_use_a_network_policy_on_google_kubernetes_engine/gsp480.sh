#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE

export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                            Clone demo"
echo "======================================================================"
gsutil cp -r gs://spls/gsp480/gke-network-policy-demo .
cd gke-network-policy-demo
chmod -R 755 *

echo "======================================================================"
echo "                       Task 1. Lab setup"
echo "======================================================================"
make setup-project
cat terraform/terraform.tfvars
make tf-apply ARGS="-auto-approve"


echo "======================================================================"
echo "                       Task 2. Validation"
echo "======================================================================"
cat > setup.sh << EOF
#!/bin/bash

sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin -y
echo "export USE_GKE_GCLOUD_AUTH_PLUGIN=True" >> ~/.bashrc
source ~/.bashrc

gcloud container clusters get-credentials gke-demo-cluster --zone $ZONE

kubectl apply -f ./manifests/hello-app/


echo "======================================================================"
echo "          Task 4. Confirming default access to the hello server"
echo "======================================================================"

echo "======================================================================"
echo "          Task 5. Restricting access with a Network Policy"
echo "======================================================================"

echo "======================================================================"
echo "          Task 6. Restricting namespaces with Network Policies"
echo "======================================================================"
kubectl delete -f ./manifests/network-policy.yaml
kubectl create -f ./manifests/network-policy-namespaced.yaml
kubectl -n hello-apps apply -f ./manifests/hello-app/hello-client.yaml


echo "======================================================================"
echo "                      Task 7. Validation"
echo "======================================================================"

echo "======================================================================"
echo "                          Task 8. Teardown"
echo "======================================================================"
echo "======================================================================"
echo "          Task 9. Troubleshooting in your own environment"
echo "======================================================================"

EOF


gcloud compute ssh gke-demo-bastion \
    --zone=$ZONE \
    --quiet \
    --project=$PROJECT_ID \
    --command="bash -s" < ./setup.sh


echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"