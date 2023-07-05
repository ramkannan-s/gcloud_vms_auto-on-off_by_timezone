#! /bin/bash

# Set variables for GCP
PROJECT_ID="${1:?please enter Project ID. ex - soleng-dev}"
dry_run="${2:?Set dry_run to true or false. ex - true}"
VM_FILE_NAME="vm_list_with_owners.txt"
SQL_FILE_NAME="sql_list_with_owners.txt"

gcloud compute instances list --project $PROJECT_ID --filter='labels!=owner AND labels!=goog-gke-node' --format='value[separator=":"](name,zone)' > $VM_FILE_NAME
gcloud sql instances list --project $PROJECT_ID --filter='labels!=owner AND labels!=goog-gke-node' --format='value[separator=":"](name)' > $SQL_FILE_NAME

while IFS= read -r vm_owner_data; do
  VM_NAME=$(echo $vm_owner_data | cut -d ':' -f1)
  ZONE=$(echo $vm_owner_data | cut -d ':' -f2)
  STATE=$(gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(status)')
  echo -e "\nNO OWNER - VM Name ==> $VM_NAME, its ZONE ==> $ZONE, its STATE ==> $STATE ...!!"
  if [ "$STATE" == "RUNNING" ]; then
    echo -e "STOP THE VM $VM_NAME [Running in DRY_RUN Mode]"
    if [ "$dry_run" = false ]; then
      echo -e "DRY_RUN is false. Hence perform STOP VM action.."
      gcloud compute instances stop "$VM_NAME" --zone "$ZONE" --project $PROJECT_ID
    fi
  fi
done < $VM_FILE_NAME

while IFS= read -r owner_data; do
  SQL_NAME=$(echo $owner_data | cut -d ':' -f2)
  STATE=$(gcloud sql instances describe "$SQL_NAME" --project "$PROJECT_ID" --format='value(state)')
  echo -e "\nSQL Name ==> $SQL_NAME, its STATE ==> $STATE ..!!"
  if [ "$STATE" == "RUNNABLE" ]; then
    echo -e "STOP THE SQL Instance - $SQL_NAME [Running in DRY_RUN Mode]"
    if [ "$dry_run" = false ]; then
      echo -e "DRY_RUN is false. Hence perform STOP SQL Instance action.."
      gcloud sql instances patch "$SQL_NAME" --activation-policy=NEVER --project $PROJECT_ID
    fi
  fi
done < $SQL_FILE_NAME

rm -rf $VM_FILE_NAME
rm -rf $SQL_FILE_NAME

### sample cmd to run - ./vm_shutdown_no_owner.sh soleng-dev true