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
echo "       Task 2. Choosing the right machine type for the Hello app"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                        Scale up Hello app"
echo "----------------------------------------------------------------------"
gcloud container clusters get-credentials hello-demo-cluster --zone $ZONE

kubectl scale deployment hello-server --replicas=2

read -p "CHECK the TASK PROGRESS and hit ENTER ..."

gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool \
    --num-nodes 4 --zone $ZONE --quiet

echo "----------------------------------------------------------------------"
echo "                     Migrate to optimized node pool"
echo "----------------------------------------------------------------------"
gcloud container node-pools create larger-pool \
  --cluster=hello-demo-cluster \
  --machine-type=e2-standard-2 \
  --num-nodes=1 \
  --zone=$ZONE

read -p "CHECK the TASK PROGRESS and hit ENTER ..."

echo "----------------------------------------------------------------------"
echo "                     Cordon the original node pool:"
echo "----------------------------------------------------------------------"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl cordon "$node";
done

echo "----------------------------------------------------------------------"
echo "                         Drain the pool:"
echo "----------------------------------------------------------------------"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node";
done


gcloud container node-pools delete my-node-pool \
    --cluster hello-demo-cluster \
    --zone $ZONE \
    --quiet


echo "======================================================================"
echo "                  Task 3. Managing a regional cluster"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                               Setup"
echo "----------------------------------------------------------------------"
gcloud container clusters create regional-demo --region=$REGION --num-nodes=1

cat << EOF > pod-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  labels:
    security: demo
spec:
  containers:
  - name: container-1
    image: wbitt/network-multitool
EOF

kubectl apply -f pod-1.yaml

cat << EOF > pod-2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF

kubectl apply -f pod-2.yaml

read -p "CHECK the TASK PROGRESS and hit ENTER ..."


export POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')

echo "----------------------------------------------------------------------"
echo "                          Simulate traffic"
echo "----------------------------------------------------------------------"
#!/bin/bash
echo "Targeting pod-2 at IP: $POD_2_IP"

# 2. Execute the ping from pod-1
echo "Starting ping from pod-1 to pod-2..."
kubectl exec pod-1 -- ping -c 50000 $POD_2_IP

read -p "Examine flow logs, create a sink, run SQL request and hit ENTER ..."

echo "----------------------------------------------------------------------"
echo "         Move a chatty pod to minimize cross-zonal traffic costs"
echo "----------------------------------------------------------------------"
sed -i 's/podAntiAffinity/podAffinity/g' pod-2.yaml
kubectl delete pod pod-2
kubectl create -f pod-2.yaml

read -p "CHECK the TASK PROGRESS and hit ENTER ..."


kubectl get pod pod-1 pod-2 --output wide

export POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')
kubectl exec pod-1 -- ping -c 50000 $POD_2_IP

echo "======================================================================"
echo "                        JOB is DONE !!!"
echo "======================================================================"