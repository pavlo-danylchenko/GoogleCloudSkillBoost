#!/bin/bash
set -euo pipefail

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo "======================================================================"
echo "                Task 9. Create the development environment"
echo "======================================================================"

echo "----------------------------------------------------------------------"
echo "                    Create a development branch"
echo "----------------------------------------------------------------------"
cd continuous-deployment-on-kubernetes/sample-app
git checkout -b new-feature

echo "----------------------------------------------------------------------"
echo "                    Modify the pipeline definition"
echo "----------------------------------------------------------------------"
sed -i "s/REPLACE_WITH_YOUR_PROJECT_ID/$DEVSHELL_PROJECT_ID/g" Jenkinsfile

sed -i "s/CLUSTER_ZONE = \".*\"/CLUSTER_ZONE = \"$ZONE\"/" Jenkinsfile

sed -i 's/<div class="card blue">/<div class="card orange">/g' html.go

sed -i 's/const version string = "1.0.0"/const version string = "2.0.0"/g' main.go

echo "======================================================================"
echo "                      Task 10. Start deployment"
echo "======================================================================"
git add Jenkinsfile html.go main.go
git commit -m "Version 2.0.0"
git push origin new-feature


echo "======================================================================"
echo "                     Task 11. Deploy a canary release"
echo "======================================================================"
git checkout -b canary
git push origin canary


echo "======================================================================"
echo "                     Task 12. Deploy to production"
echo "======================================================================"
git checkout master
git merge canary
git push origin master