export ZONE=europe-west1-c
gcloud compute instances create multi-nic-v --zone=$ZONE --machine-type=e2-medium --network-interface=network=my-vpc1,subnet=subnet-a --network-interface=network=my-vpc2,subnet=subnet-b
