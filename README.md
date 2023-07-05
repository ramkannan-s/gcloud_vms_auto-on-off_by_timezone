# gcloud_vms_auto-on-off_by_timezone

There are 4 pipelines currently running :-
1. Shutdown VM's based on TimeZone - Runs every 1 hr on Weekdays.
2. Shutdown ALL VM and SQL DB's - Run every 8 hrs on weekends.
3. Shutdown SQL DB's based on TimeZone - Runs every 2 hrs on Weekdays.
4. Shutdown ALL VM and SQL DB's without OWNER - Run every 30min on Weekdays.