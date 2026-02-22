export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud compute instance-groups managed create dev-instance-group \
    --zone=$ZONE \
    --template=dev-instance-template \
    --size=1
gcloud compute instance-groups managed set-autoscaling dev-instance-group \
    --zone=$ZONE \
    --mode=on \
    --min-num-replicas=1 \
    --max-num-replicas=3 \
    --target-cpu-utilization=0.6