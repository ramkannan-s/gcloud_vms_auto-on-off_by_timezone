#! /bin/bash

# Set variables for GCP
PROJECT_ID="${1:?please enter Project ID. ex - soleng-dev}"
dry_run="${2:?Set dry_run to true or false. ex - true}"
VM_FILE_NAME="vm_list_with_owners.txt"

gcloud compute instances list --project $PROJECT_ID --filter='labels.owner:* AND labels!=goog-gke-node' --format='value[separator=":"](labels.owner,name,zone)' > $VM_FILE_NAME

while IFS= read -r vm_owner_data; do
  OWNER=$(echo $vm_owner_data | cut -d ':' -f1)
  VM_NAME=$(echo $vm_owner_data | cut -d ':' -f2)
  ZONE=$(echo $vm_owner_data | cut -d ':' -f3)
  STATE=$(gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(status)')
  checkLabelByPass=$(gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(labels.auto_shutdown_bypass)')
  echo -e "\nVM Name ==> $VM_NAME, its OWNER ==> $OWNER, its ZONE ==> $ZONE, its STATE ==> $STATE ...!!"

  if [ -z "$checkLabelByPass" ]; then
    if [ "$STATE" == "RUNNING" ]; then
      echo -e "STOP THE VM $VM_NAME [Running in DRY_RUN Mode]"
      if [ "$dry_run" = false ]; then
        echo -e "DRY_RUN is false. Hence perform STOP VM action.."
        gcloud compute instances stop "$VM_NAME" --zone "$ZONE" --project $PROJECT_ID
      fi
    fi
  else
    echo -e "Label auto_shutdown_bypass is set to $checkLabelByPass. Hence skipping to STOP this VM - $VM_NAME."
  fi
done < $VM_FILE_NAME

rm -rf $VM_FILE_NAME

### sample cmd to run - ./vm_shutdown_all.sh soleng-dev true