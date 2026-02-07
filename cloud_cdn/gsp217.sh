#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 1. Create and populate a Cloud Storage bucket"
echo "======================================================================"
gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID \
    --location=ASIA --project=$DEVSHELL_PROJECT_ID --no-public-access-prevention

echo "----------------------------------------------------------------------"
echo "                  Copy an image file into your bucket"
echo "----------------------------------------------------------------------"
gsutil cp gs://spls/gsp217/cdn/cdn.png gs://$DEVSHELL_PROJECT_ID
gsutil iam ch allUsers:objectViewer gs://$DEVSHELL_PROJECT_ID


echo "======================================================================"
echo "            Task 2. Create the HTTP Load Balancer with Cloud CDN"
echo "======================================================================"
export LB_NAME=cdn-lb

echo "----------------------------------------------------------------------"
echo "                 Create Backend Bucket with CDN enabled"
echo "----------------------------------------------------------------------"
gcloud compute backend-buckets create cdn-bucket \
    --gcs-bucket-name=$DEVSHELL_PROJECT_ID \
    --enable-cdn \
    --cache-mode=CACHE_ALL_STATIC \
    --client-ttl=60 \
    --default-ttl=60 \
    --max-ttl=60

echo "----------------------------------------------------------------------"
echo "                          Create URL Map"
echo "----------------------------------------------------------------------"
gcloud compute url-maps create $LB_NAME \
    --default-backend-bucket=cdn-bucket

echo "----------------------------------------------------------------------"
echo "                    Set up Frontend (Target HTTP Proxy)"
echo "----------------------------------------------------------------------"
gcloud compute target-http-proxies create $LB_NAME-target-proxy \
    --url-map=$LB_NAME

echo "----------------------------------------------------------------------"
echo "                Reserve IP and create Forwarding Rule"
echo "----------------------------------------------------------------------"
gcloud compute forwarding-rules create $LB_NAME-forwarding-rule \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --address-region=global \
    --global \
    --target-http-proxy=$LB_NAME-target-proxy \
    --ports=80

echo "----------------------------------------------------------------------"
echo "                           Get IP-address"
echo "----------------------------------------------------------------------"
export LB_IP_ADDRESS=$(gcloud compute forwarding-rules describe $LB_NAME-forwarding-rule \
    --global --format="value(IPAddress)")


echo "======================================================================"
echo "     Task 3. Verify the caching of bucket's content (OPTIONAL)"
echo "======================================================================"
for i in {1..3}; do
    curl -s -o /dev/null -w "%{time_total}\n" http://$LB_IP_ADDRESS/cdn.png;
done


# PUT https://compute.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-a6b5c1958133/global/backendBuckets/cdn-bucket
# {
#   "bucketName": "qwiklabs-gcp-02-a6b5c1958133",
#   "cdnPolicy": {
#     "cacheMode": "CACHE_ALL_STATIC",
#     "clientTtl": 60,
#     "defaultTtl": 60,
#     "maxTtl": 60,
#     "negativeCaching": true,
#     "requestCoalescing": true,
#     "serveWhileStale": 86400
#   },
#   "compressionMode": "DISABLED",
#   "description": "",
#   "enableCdn": true,
#   "name": "cdn-bucket",
#   "usedBy": [
#     {
#       "reference": "https://www.googleapis.com/compute/beta/projects/qwiklabs-gcp-02-a6b5c1958133/global/urlMaps/cdn-lb"
#     }
#   ]
# }

# PATCH https://compute.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-a6b5c1958133/global/targetHttpProxies/cdn-lb-proxy
# {
#   "fingerprint": "X3AGOqoBRTY=",
#   "httpKeepAliveTimeoutSec": 60
# }

# OPTION # 2
# POST https://compute.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-a6b5c1958133/global/backendBuckets
# {
#   "bucketName": "qwiklabs-gcp-02-a6b5c1958133",
#   "cdnPolicy": {
#     "cacheMode": "CACHE_ALL_STATIC",
#     "clientTtl": 60,
#     "defaultTtl": 60,
#     "maxTtl": 60,
#     "negativeCaching": false,
#     "serveWhileStale": 0
#   },
#   "compressionMode": "DISABLED",
#   "description": "",
#   "enableCdn": true,
#   "name": "cdn-bucket"
# }

# POST https://compute.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-a6b5c1958133/global/urlMaps
# {
#   "defaultService": "projects/qwiklabs-gcp-02-a6b5c1958133/global/backendBuckets/cdn-bucket",
#   "name": "cdn-lb"
# }

# POST https://compute.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-a6b5c1958133/global/targetHttpProxies
# {
#   "name": "cdn-lb-target-proxy",
#   "urlMap": "projects/qwiklabs-gcp-02-a6b5c1958133/global/urlMaps/cdn-lb"
# }

# POST https://compute.googleapis.com/compute/beta/projects/qwiklabs-gcp-02-a6b5c1958133/global/forwardingRules
# {
#   "IPProtocol": "TCP",
#   "ipVersion": "IPV4",
#   "loadBalancingScheme": "EXTERNAL_MANAGED",
#   "name": "cdn-lb",
#   "networkTier": "PREMIUM",
#   "portRange": "80",
#   "target": "projects/qwiklabs-gcp-02-a6b5c1958133/global/targetHttpProxies/cdn-lb-target-proxy"
# }