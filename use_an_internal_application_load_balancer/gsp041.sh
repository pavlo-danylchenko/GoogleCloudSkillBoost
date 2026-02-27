#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

read -p "ENTER IP_ADDRESS_1: " IP_ADDRESS_1
read -p "ENTER IP_ADDRESS_2: " IP_ADDRESS_2

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
echo $ZONE
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo "======================================================================"
echo "                 Task 1. Create a virtual environment"
echo "======================================================================"
sudo apt-get install -y virtualenv
python3 -m venv venv
source venv/bin/activate

echo "======================================================================"
echo "              Task 2. Create a backend managed instance group"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                    Create the startup script"
echo "----------------------------------------------------------------------"
cat > ~/backend.sh << EOF1
sudo chmod -R 777 /usr/local/sbin/
sudo cat << EOF > /usr/local/sbin/serveprimes.py
import http.server

def is_prime(a): return a!=1 and all(a % i for i in range(2,int(a**0.5)+1))

class myHandler(http.server.BaseHTTPRequestHandler):
  def do_GET(s):
    s.send_response(200)
    s.send_header("Content-type", "text/plain")
    s.end_headers()
    s.wfile.write(bytes(str(is_prime(int(s.path[1:]))).encode('utf-8')))

http.server.HTTPServer(("",80),myHandler).serve_forever()
EOF
nohup python3 /usr/local/sbin/serveprimes.py >/dev/null 2>&1 &
EOF1


echo "----------------------------------------------------------------------"
echo "                  Create the instance template"
echo "----------------------------------------------------------------------"
gcloud compute instance-templates create primecalc \
    --metadata-from-file startup-script=backend.sh \
    --no-address --tags backend --machine-type=e2-medium


echo "----------------------------------------------------------------------"
echo "                  Open the firewall"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create http --network default --allow=tcp:80 \
    --source-ranges $IP_ADDRESS_1 --target-tags backend

echo "----------------------------------------------------------------------"
echo "                  Create the instance group"
echo "----------------------------------------------------------------------"
gcloud compute instance-groups managed create backend \
    --size 3 \
    --template primecalc \
    --zone $ZONE

echo "======================================================================"
echo "              Task 3. Set up the internal load balancer"
echo "======================================================================"
echo "----------------------------------------------------------------------"
echo "                  Create a health check"
echo "----------------------------------------------------------------------"
gcloud compute health-checks create http ilb-health --request-path /2

echo "----------------------------------------------------------------------"
echo "                  Create a backend service"
echo "----------------------------------------------------------------------"
gcloud compute backend-services create prime-service \
    --load-balancing-scheme internal --region=$REGION \
    --protocol tcp --health-checks ilb-health

echo "----------------------------------------------------------------------"
echo "               Add the instance group to the backend service"
echo "----------------------------------------------------------------------"
gcloud compute backend-services add-backend prime-service \
    --instance-group backend --instance-group-zone=$ZONE \
    --region=$REGION

echo "----------------------------------------------------------------------"
echo "                    Create the forwarding rule"
echo "----------------------------------------------------------------------"
gcloud compute forwarding-rules create prime-lb \
    --load-balancing-scheme internal \
    --ports 80 --network default \
    --region=$REGION --address $IP_ADDRESS_2 \
    --backend-service prime-service

echo "======================================================================"
echo "              Task 5. Create a public-facing web server"
echo "======================================================================"
cat > frontend.sh << EOF1
sudo chmod -R 777 /usr/local/sbin/
sudo cat << EOF > /usr/local/sbin/getprimes.py
import urllib.request
from multiprocessing.dummy import Pool as ThreadPool
import http.server
PREFIX="http://IP/" #HTTP Load Balancer
def get_url(number):
    return urllib.request.urlopen(PREFIX+str(number)).read().decode('utf-8')
class myHandler(http.server.BaseHTTPRequestHandler):
  def do_GET(s):
    s.send_response(200)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    i = int(s.path[1:]) if (len(s.path)>1) else 1
    s.wfile.write("<html><body><table>".encode('utf-8'))
    pool = ThreadPool(10)
    results = pool.map(get_url,range(i,i+100))
    for x in range(0,100):
      if not (x % 10): s.wfile.write("<tr>".encode('utf-8'))
      if results[x]=="True":
        s.wfile.write("<td bgcolor='#00ff00'>".encode('utf-8'))
      else:
        s.wfile.write("<td bgcolor='#ff0000'>".encode('utf-8'))
      s.wfile.write(str(x+i).encode('utf-8')+"</td> ".encode('utf-8'))
      if not ((x+1) % 10): s.wfile.write("</tr>".encode('utf-8'))
    s.wfile.write("</table></body></html>".encode('utf-8'))
http.server.HTTPServer(("",80),myHandler).serve_forever()
EOF
nohup python3 /usr/local/sbin/getprimes.py >/dev/null 2>&1 &
EOF1


echo "----------------------------------------------------------------------"
echo "                    Create the frontend instance"
echo "----------------------------------------------------------------------"
gcloud compute instances create frontend --zone=$ZONE \
    --metadata-from-file startup-script=frontend.sh \
    --tags frontend --machine-type=e2-standard-2

echo "----------------------------------------------------------------------"
echo "                  Open the firewall for the frontend"
echo "----------------------------------------------------------------------"
gcloud compute firewall-rules create http2 --network default --allow=tcp:80 \
    --source-ranges 0.0.0.0/0 --target-tags frontend

echo "JOB is DONE !"