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

# gcloud config set compute/zone $ZONE
# gcloud config set compute/region $REGION

# echo "======================================================================"
# echo "                        Task 1. Hello world"
# echo "======================================================================"
# docker run hello-world
# docker images
# docker run hello-world
# docker ps
# docker ps -a


echo "======================================================================"
echo "                           Task 2. Build"
echo "======================================================================"
mkdir test && cd test

cat > Dockerfile <<EOF
# Use an official Node runtime as the parent image
FROM node:lts

# Set the working directory in the container to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

# Make the container's port 80 available to the outside world
EXPOSE 80

# Run app.js using node when the container launches
CMD ["node", "app.js"]
EOF


cat > app.js << EOF
const http = require("http");

const hostname = "0.0.0.0";
const port = 80;

const server = http.createServer((req, res) => {
	res.statusCode = 200;
	res.setHeader("Content-Type", "text/plain");
	res.end("Hello World\n");
});

server.listen(port, hostname, () => {
	console.log("Server running at http://%s:%s/", hostname, port);
});

process.on("SIGINT", function () {
	console.log("Caught interrupt signal and will exit");
	process.exit();
});
EOF

docker build -t node-app:0.1 .

docker images


echo "======================================================================"
echo "                           Task 3. Run"
echo "======================================================================"
docker run -p 4000:80 --name my-app -d node-app:0.1

curl http://localhost:4000

sed -i "s/Hello World/Welcome to Cloud/g" app.js
docker build -t node-app:0.2 .
docker run -p 8080:80 --name my-app-2 -d node-app:0.2
docker ps

curl http://localhost:8080


# echo "======================================================================"
# echo "                           Task 4. Debug"
# echo "======================================================================"
# docker logs -f [container_id]
# docker exec -it [container_id] bash
# docker inspect [container_id]
# docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' [container_id]

echo "======================================================================"
echo "                           Task 5. Publish"
echo "======================================================================"
gcloud artifacts repositories cretae my-repository --repository-format=docker \
	--location=$REGION --description="Docker repository"
gcloud auth configure-docker $REGION-docker.pkg.dev

docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/node-app:0.2 .
docker images

docker push $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/node-app:0.2

echo "----------------------------------------------------------------------"
echo "                           Test the image"
echo "----------------------------------------------------------------------"
docker stop $(docker ps -q)
docker rm $(docker ps -aq)

docker rmi $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/node-app:0.2
docker rmi node:lts
docker rmi -f $(docker images -aq) # remove remaining images
docker images


docker run -p 4000:80 -d $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/node-app:0.2
curl http://localhost:4000

echo "======================================================================"
echo "                          JOB is DONE !"
echo "======================================================================"