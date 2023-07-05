#! /bin/bash

# Set variables for GCP
PROJECT_ID="${1:?please enter Project ID. ex - soleng-dev}"
dry_run="${2:?Set dry_run to true or false. ex - true}"
SQL_FILE_NAME="sql_list_with_owners.txt"

gcloud sql instances list --project $PROJECT_ID --filter='labels.owner:* AND labels!=goog-gke-node' --format='value[separator=":"](labels.owner,name)' > $SQL_FILE_NAME

while IFS= read -r owner_data; do
  OWNER=$(echo $owner_data | cut -d ':' -f1)
  SQL_NAME=$(echo $owner_data | cut -d ':' -f2)
  STATE=$(gcloud sql instances describe "$SQL_NAME" --project "$PROJECT_ID" --format='value(state)')
  checkLabelByPass=$(gcloud sql instances describe "$SQL_NAME" --project "$PROJECT_ID" --format='value(labels.auto_shutdown_bypass)')
  echo -e "\nSQL Name ==> $SQL_NAME, its OWNER ==> $OWNER, its STATE ==> $STATE ...!!"

  if [ -z "$checkLabelByPass" ]; then
    if [ "$STATE" == "RUNNABLE" ]; then
      echo -e "STOP THE SQL Instance - $SQL_NAME"
      if [ "$dry_run" = false ]; then
        echo -e "DRY_RUN is false. Hence perform STOP SQL Instance action.."
        gcloud sql instances patch "$SQL_NAME" --activation-policy=NEVER --project $PROJECT_ID
      fi
    fi
  else
    echo -e "Label auto_shutdown_bypass is set to $checkLabelByPass. Hence skipping to STOP this VM - $SQL_NAME."
  fi
done < $SQL_FILE_NAME

rm -rf $SQL_FILE_NAME

### sample cmd to run - ./sql_shutdown_all.sh soleng-dev true