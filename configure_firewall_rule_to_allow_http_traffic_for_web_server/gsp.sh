gcloud compute firewall-rules update allow-http-rule \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=allow-http