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
gcloud config set dataproc/region $REGION


echo "======================================================================"
echo "          Task 1. Create a development machine in Compute Engine"
echo "======================================================================"
gcloud compute instances create devhost \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=TERMINATE \
    --provisioning-model=STANDARD \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk=auto-delete=yes,boot=yes,device-name=devhost,image=projects/debian-cloud/global/images/family/debian-12,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy-id=ops-agent-get-started-policy-1-0-0 \
    --reservation-affinity=any



cat > start.sh << 'EOF'
#!/bin/bash

echo "======================================================================"
echo "                       Task 2. Install software"
echo "======================================================================"
sudo apt-get install -y dirmngr unzip
sudo apt-get update
sudo apt-get install -y apt-transport-https
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
sudo apt-get update
sudo apt-get install -y bc scala sbt

sudo apt-get update
gsutil cp gs://spls/gsp124/cloud-dataproc.zip .
unzip cloud-dataproc.zip
cd cloud-dataproc/codelabs/opencv-haarcascade
sbt assembly


echo "======================================================================"
echo "        Task 3. Create a Cloud Storage bucket and collect images"
echo "======================================================================"
export MYBUCKET="${USER//google}-image-${RANDOM}"
echo MYBUCKET=${MYBUCKET}
gsutil mb gs://${MYBUCKET}


curl https://www.publicdomainpictures.net/pictures/20000/velka/family-of-three-871290963799xUk.jpg | gsutil cp - gs://${MYBUCKET}/imgs/family-of-three.jpg
curl https://www.publicdomainpictures.net/pictures/10000/velka/african-woman-331287912508yqXc.jpg | gsutil cp - gs://${MYBUCKET}/imgs/african-woman.jpg
curl https://www.publicdomainpictures.net/pictures/10000/velka/296-1246658839vCW7.jpg | gsutil cp - gs://${MYBUCKET}/imgs/classroom.jpg


echo "======================================================================"
echo "              Task 4. Create a Cloud Dataproc cluster"
echo "======================================================================"
export MYCLUSTER="${USER/_/-}-qwiklab"
echo MYCLUSTER=${MYCLUSTER}
gcloud dataproc clusters create ${MYCLUSTER} \
    --bucket=${MYBUCKET} \
    --worker-machine-type=e2-standard-2 \
    --master-machine-type=e2-standard-2 \
    --initialization-actions=gs://spls/gsp010/install-libgtk.sh \
    --image-version=2.0 \
    --worker-boot-disk-size=30GB \
    --master-boot-disk-size=30GB 



echo "======================================================================"
echo "               Task 5. Submit your job to Cloud Dataproc"
echo "======================================================================"
curl https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_frontalface_default.xml | gsutil cp - gs://${MYBUCKET}/haarcascade_frontalface_default.xml
cd ~/cloud-dataproc/codelabs/opencv-haarcascade
gcloud dataproc jobs submit spark \
    --cluster ${MYCLUSTER} \
    --jar target/scala-2.12/feature_detector-assembly-1.0.jar -- \
    gs://${MYBUCKET}/haarcascade_frontalface_default.xml \
    gs://${MYBUCKET}/imgs/ \
    gs://${MYBUCKET}/out/
EOF

echo "Sending the script to the VM instance ..."
# gcloud compute scp ./start.sh linux-instance:~/ --zone=$ZONE

# To execute once:
gcloud compute ssh devhost \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh


echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"