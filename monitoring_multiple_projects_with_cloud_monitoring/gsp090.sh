#!/bin/bash
set -euo pipefail

# Define a function to export and assign the project variables
assign_projects() {
  # Get the list of projects and extract project IDs using gcloud command
  PROJECT_LIST=$(gcloud projects list --format="value(projectId)")

  # Ask the user to enter the project ID for PROJECT_2
  echo -n "Please Enter the PROJECT_2 ID: "
  read PROJECT_2
  
  # Check if the entered PROJECT_2 ID is valid
  if [[ ! "$PROJECT_LIST" =~ (^|[[:space:]])"$PROJECT_2"($|[[:space:]]) ]]; then
    echo "Invalid project ID. Please enter a valid project ID from the list."
    return 1
  fi
  
  # Find a project to assign to PROJECT_1
  # Exclude PROJECT_2 from the list and pick the first available project ID
  PROJECT_1=$(echo "$PROJECT_LIST" | grep -v "^$PROJECT_2$" | head -n 1)

  # Check if PROJECT_1 was assigned
  if [[ -z "$PROJECT_1" ]]; then
    echo "No other project available to assign to PROJECT_1."
    return 1
  fi

  # Export the selected project IDs
  export PROJECT_2
  export PROJECT_1
  
  # Print the results
  echo
  echo "$PROJECT_1 has been set to: $PROJECT_1"
  echo "PROJECT_2 has been set to: $PROJECT_2"
}

# Call the function
assign_projects

# Step 2: Setting gcloud project
echo "Setting gcloud project to $PROJECT_2..."
gcloud config set project $PROJECT_2

# Step 3: Get the zone and create a VM instance
echo "Creating a VM instance in the project zone..."
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# Task 1. Create Project 2's virtual machine

gcloud compute instances create instance2 \
    --zone=$ZONE \
    --machine-type=e2-medium

echo

echo "Create a Monitoring Metrics Scope"
gcloud monitoring metrics-scopes projects add \
    projects/$PROJECT_1 \
    --metrics-scope=projects/$PROJECT_2

echo "Create a Cloud Monitoring group"
cat > group-config.json <<EOF_END
{
  "displayName": "DemoGroup",
  "filter": "resource.metadata.name = has_substring(\"instance\")"
}
EOF_END

gcloud monitoring groups create \
    --group-from-file="group-config.json" \
    --project=$PROJECT_2

GROUP_ID=$(gcloud monitoring groups list --filter="displayName=DemoGroup" --format="value(name)")


cat > uptime-check-config.json <<EOF_END
{
  "displayName": "DemoGroup uptime check",
  "period": "60s",
  "timeout": "10s",
  "tcpCheck": {
    "port": 22
  },
  "resourceGroup": {
    "resourceType": "Instance",
    "groupId": "$GROUP_ID"
  },
  "selectedRegions": [
    "USA",
    "EUROPE",
    "ASIA_PACIFIC"
  ]
}
EOF_END
# Step 4: Provide a link to monitor the metric scope
echo "Click here to monitor metrics: https://console.cloud.google.com/monitoring/settings/metric-scope?project=$PROJECT_2"

# Function to prompt user to check their progress
function check_progress {
    while true; do
        echo
        echo -n "$Have you created Group DemoGroup (instance) & Uptime check '"DemoGroup uptime check"'? (Y/N): "
        read -r user_input
        if [[ "$user_input" == "Y" || "$user_input" == "y" ]]; then
            echo
            echo "$Great! Proceeding to the next steps..."
            echo
            break
        elif [[ "$user_input" == "N" || "$user_input" == "n" ]]; then
            echo
            echo "$Please create Groups named DemoGroup and then press Y to continue."
        else
            echo
            echo "$Invalid input. Please enter Y or N."
        fi
    done
}

# Call function to check progress before proceeding
check_progress

# Task 4. Alerting policy for the group
UPTIME_CHECK_ID=$(gcloud monitoring uptime-checks list \
    --filter="displayName='DemoGroup uptime check'" \
    --format="value(name)" | cut -d'/' -f4)

echo "ID UPTIME CHECK: $UPTIME_CHECK_ID"
cat > uptime-check-policy.json <<EOF_END
{
  "displayName": "Uptime Check Policy",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Uptime Check Absence on DemoGroup",
      "conditionAbsent": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"$UPTIME_CHECK_ID\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_FRACTION_TRUE"
          }
        ],
        "duration": "300s",
        "trigger": {
          "count": 1
        }
      }
    }
  ],
  "enabled": true
}
EOF_END

gcloud monitoring policies create --policy-from-file="uptime-check-policy.json"

# # Step 5: Create a monitoring policy JSON file
# echo "Creating monitoring policy JSON file..."
# cat > uptime-check-policy.json <<EOF_END
# {
#   "displayName": "Uptime Check Policy",
#   "userLabels": {},
#   "conditions": [
#     {
#       "displayName": "VM Instance - Check passed",
#       "conditionAbsent": {
#         "filter": "resource.type = \"gce_instance\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"demogroup-uptime-check-f-UeocjSHdQ\"",
#         "aggregations": [
#           {
#             "alignmentPeriod": "300s",
#             "crossSeriesReducer": "REDUCE_NONE",
#             "perSeriesAligner": "ALIGN_FRACTION_TRUE"
#           }
#         ],
#         "duration": "300s",
#         "trigger": {
#           "count": 1
#         }
#       }
#     }
#   ],
#   "alertStrategy": {},
#   "combiner": "OR",
#   "enabled": true,
#   "notificationChannels": [],
#   "severity": "SEVERITY_UNSPECIFIED"
# }
# EOF_END

# # Step 6: Create monitoring policy using gcloud command
# echo "Creating monitoring policy..."
# gcloud monitoring policies create --policy-from-file="uptime-check-policy.json"

echo "Job is Done!"