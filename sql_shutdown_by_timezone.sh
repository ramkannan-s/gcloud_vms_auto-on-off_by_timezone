#! /bin/bash

# Set variables for GCP
PROJECT_ID="${1:?please enter Project ID. ex - soleng-dev}"

# Set your Slack API token
SLACK_TOKEN="${2:?please enter Slack Token ID. ex - xoxb-****}"
dry_run="${3:?Set dry_run to true or false. ex - true}"
SLACK_FILE_NAME="slack_data.txt"
SQL_FILE_NAME="sql_list_with_owners.txt"

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

gcloud sql instances list --project $PROJECT_ID --filter='labels.owner:* AND labels!=goog-gke-node' --format='value[separator=":"](labels.owner,name)' > $SQL_FILE_NAME

while IFS= read -r owner_data; do
  OWNER=$(echo $owner_data | cut -d ':' -f1)
  SQL_NAME=$(echo $owner_data | cut -d ':' -f2)
  loc_of_owner=$(cat $SLACK_FILE_NAME | grep "$OWNER" | head -n 1 | cut -d ' ' -f 3)
  STATE=$(gcloud sql instances describe "$SQL_NAME" --project "$PROJECT_ID" --format='value(state)')
  checkLabelByPass=$(gcloud sql instances describe "$SQL_NAME" --project "$PROJECT_ID" --format='value(labels.auto_shutdown_bypass)')
  echo -e "\nVM Name ==> $SQL_NAME, its OWNER ==> $OWNER, its STATE ==> $STATE and Location ==> $loc_of_owner...!!"

  if [ -z "$checkLabelByPass" ]; then
    if [ -z "$loc_of_owner" ]; then
      echo "Location is empty. Check the OWNER Name. Current OWNER Label is $OWNER...!!!"
    else
      # Set timezone
      export TZ="$loc_of_owner"

      # Get current hour in 24-hour format
      current_hour=$(date +%H)

      # Check if current hour is between 8am and 9am for starting the VM and stop the VM between 6pm to 7pm in respective timezones
      if [ "$current_hour" -ge 8 ] && [ "$current_hour" -lt 9 ]; then
          echo -e "Current time is between 9am and 6pm in $TZ timezone. Here leave the VM - $SQL_NAME in running state or start the VM."
          if [ "$STATE" == "STOPPED" ]; then
            echo -e "START THE SQL Instance - $SQL_NAME"
            if [ "$dry_run" = false ]; then
              echo -e "dry_run is false. Hence perform Start SQL Instance action.."
              #gcloud sql instances patch "$SQL_NAME" --activation-policy=ALWAYS --project $PROJECT_ID
            fi
            
          fi
      elif [ "$current_hour" -ge 18 ] && [ "$current_hour" -lt 19 ]; then
          echo -e "Current time is NOT between 9am and 6pm in $TZ timezone. Hence Shutdown the VM - $SQL_NAME or keep it in stopped state."
          if [ "$STATE" == "RUNNABLE" ]; then
            echo -e "STOP THE SQL Instance - $SQL_NAME"
            if [ "$dry_run" = false ]; then
              echo -e "dry_run is false. Hence perform Stop SQL Instance action.."
              gcloud sql instances patch "$SQL_NAME" --activation-policy=NEVER --project $PROJECT_ID
            fi
          fi
      fi
    fi
  else
    echo -e "Label auto_shutdown_bypass is set to $checkLabelByPass. Hence skipping any check on this VM - $VM_NAME."
  fi
done < $SQL_FILE_NAME

rm -rf $SLACK_FILE_NAME
rm -rf $SQL_FILE_NAME

### sample cmd to run - ./sql_shutdown_by_timezone.sh soleng-dev xoxb-**** true
