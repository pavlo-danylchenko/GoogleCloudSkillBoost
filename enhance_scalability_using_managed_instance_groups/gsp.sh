export REGION=us-west1

gcloud compute instance-groups managed create dev-instance-group --region=REGION --template=dev-instance-template --size=1
gcloud compute instance-groups managed set-autoscaling dev-instance-group --region=$REGION --mode=on --min-num-replicas=1 --max-num-replicas=3 --target-cpu-utilization=0.6