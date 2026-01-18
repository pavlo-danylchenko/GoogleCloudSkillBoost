#!/bin/bash
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

# Task 4. Create a custom role
# Create a custom role using a YAML file
echo "${YELLOW}${BOLD}Starting${RESET}" "${GREEN}${BOLD}Execution${RESET}"

echo 'title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete' > role-definition.yaml

gcloud iam roles create editor --project $DEVSHELL_PROJECT_ID \
--file role-definition.yaml

# Create a custom role using flags
gcloud iam roles create viewer --project $DEVSHELL_PROJECT_ID \
--title "Role Viewer" --description "Custom role description." \
--permissions compute.instances.get,compute.instances.list --stage ALPHA

# Task 5. List the custom roles
gcloud iam roles list --project $DEVSHELL_PROJECT_ID
gcloud iam roles list


# Task 6. Update an existing custom role
# Update a custom role using a YAML file
echo 'description: Edit access for App Versions
etag:
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
- storage.buckets.get
- storage.buckets.list
name: projects/'$DEVSHELL_PROJECT_ID'/roles/editor
stage: ALPHA
title: Role Editor' > new-role-definition.yaml

gcloud iam roles update editor --project $DEVSHELL_PROJECT_ID \
--file new-role-definition.yaml --quiet

# Update a custom role using flags
gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
--add-permissions storage.buckets.get,storage.buckets.list

# Task 7. Disable a custom role
gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
--stage DISABLED

# Task 8. Delete a custom role
gcloud iam roles delete viewer --project $DEVSHELL_PROJECT_ID

# Task 9. Restore a custom role
gcloud iam roles undelete viewer --project $DEVSHELL_PROJECT_ID

echo "${RED}${BOLD}Congratulations${RESET}" "${WHITE}${BOLD}for${RESET}" "${GREEN}${BOLD}Completing the Lab !!!${RESET}"

