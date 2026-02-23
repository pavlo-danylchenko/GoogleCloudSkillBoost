BUCKET_NAME=
BACKEND_BUCKET=static-backend-bucket
URL_MAP=cdn-map
PROXY=cdn-http-proxy
FORWARDING_RULE=cdn-http-rule

gcloud compute backend-buckets create $BACKEND_BUCKET --gcs-bucket-name=$BUCKET_NAME --enable-cdn

gcloud compute url-maps create $URL_MAP --default-backend-bucket=$BACKEND_BUCKET

gcloud compute target-http-proxies create $PROXY --url-map=$URL_MAP

gcloud compute forwarding-rules create $FORWARDING_RULE --global --target-http-proxy=$PROXY --ports=80

export IP_ADDRESS=$(gcloud compute forwarding-rules describe $FORWARDING_RULE --global --format="value(IPAddress)")

gsutil ls gs://BUCKET_NAME/images/

curl -o nature.png http://$IP_ADDRESS/images/nature.png