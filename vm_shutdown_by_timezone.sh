#! /bin/bash

# Set variables for GCP
PROJECT_ID="${1:?please enter Project ID. ex - soleng-dev}"

# Set your Slack API token
SLACK_TOKEN="${2:?please enter Slack Token ID. ex - xoxb-****}"
dry_run="${3:?Set dry_run to True or False. ex - xoxb-****}"
SLACK_FILE_NAME="slack_data.txt"
VM_FILE_NAME="vm_list_with_owners.txt"

# Make initial request to users.list
response=$(curl -s -X GET \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H 'Content-type: application/json' \
  "https://slack.com/api/users.list?include_locale=true")

# Get first 1000 users
echo "user_id,name,real_name,location" > $SLACK_FILE_NAME
echo $response | jq -r '.members[] | "\(.name) == \(.tz)"' | sort >> $SLACK_FILE_NAME

# Get next batch of users (if any)
cursor=$(echo $response | jq -r '.response_metadata.next_cursor')
while [[ "$cursor" != "null" ]]; do
  response=$(curl -s -X GET \
    -H "Authorization: Bearer $SLACK_TOKEN" \
    -H 'Content-type: application/json' \
    "https://slack.com/api/users.list?include_locale=true&cursor=$cursor")
  echo $response | jq -r '.members[] | "\(.name) == \(.tz)"' | sort >> $SLACK_FILE_NAME
  cursor=$(echo $response | jq -r '.response_metadata.next_cursor')
done

gcloud compute instances list --project $PROJECT_ID --filter='labels.owner:* AND labels!=goog-gke-node' --format='value[separator=":"](labels.owner,name,zone)' > $VM_FILE_NAME

while IFS= read -r vm_owner_data; do
  OWNER=$(echo $vm_owner_data | cut -d ':' -f1)
  VM_NAME=$(echo $vm_owner_data | cut -d ':' -f2)
  ZONE=$(echo $vm_owner_data | cut -d ':' -f3)
  loc_of_owner=$(cat $SLACK_FILE_NAME | grep "$OWNER" | head -n 1 | cut -d ' ' -f 3)
  STATE=$(gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(status)')
  echo -e "\nVM Name ==> $VM_NAME, its OWNER ==> $OWNER, its ZONE ==> $ZONE, its STATE ==> $STATE and Location ==> $loc_of_owner...!!"

  if [ -z "$loc_of_owner" ]; then
    echo "Location is empty. Check the OWNER Name. Current OWNER Label is $OWNER...!!!"
  else
    # Set timezone
    export TZ="$loc_of_owner"

    # Get current hour in 24-hour format
    current_hour=$(date +%H)

    # Check if current hour is between 8am and 9am for starting the VM and stop the VM between 6pm to 7pm in respective timezones
    if [ "$current_hour" -ge 8 ] && [ "$current_hour" -lt 9 ]; then
        echo -e "Current time is between 9am and 6pm in $TZ timezone. Here leave the VM - $VM_NAME in running state or start the VM."
        if [ "$STATE" == "TERMINATED" ]; then
          echo -e "START THE VM $VM_NAME"
          if [ "$dry_run" = false ]; then
            echo -e "dry_run is false. Hence perform start vm action.."
            gcloud compute instances start "$VM_NAME" --zone "$ZONE" --project $PROJECT_ID
          fi
          
        fi
    elif [ "$current_hour" -ge 18 ] && [ "$current_hour" -lt 19 ]; then
        echo -e "Current time is NOT between 9am and 6pm in $TZ timezone. Hence Shutdown the VM - $VM_NAME or keep it in stopped state."
        if [ "$STATE" == "RUNNING" ]; then
          echo -e "STOP THE VM $VM_NAME"
          if [ "$dry_run" = false ]; then
            echo -e "dry_run is false. Hence perform stop vm action.."
            gcloud compute instances stop "$VM_NAME" --zone "$ZONE" --project $PROJECT_ID --keep-disks
          fi
        fi
    fi
  fi
done < $VM_FILE_NAME

rm -rf $SLACK_FILE_NAME
rm -rf $VM_FILE_NAME

### sample cmd to run - ./vm_shutdown_by_timezone.sh soleng-dev xoxb-**** true
