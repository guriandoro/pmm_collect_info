#!/bin/bash

### PMM-CLIENT OUTPUTS COLLECTION ###
echo "Gathering outputs from PMM client..."

if [ -d pmm_client_collected ]
then
  echo "ERROR: pmm_client_collected directory should not be created."
  echo "Aborting execution."
  # We remove the directory that we created before, so next executions
  # don't fail because of that check
  rm -rf pmm_server_collected
  exit 1
fi

mkdir pmm_client_collected 2>/dev/null
cd pmm_client_collected

pt-summary --sleep=1 > pt-summary.txt

#todo: add support for pt-mysql-summary pt-mongodb-summary ... etc

which netstat && netstat -punta > netstat_punta.txt
which pmm-admin && pmm-admin check-network > pmm_admin-check-network.txt
which pmm-admin && pmm-admin list > pmm_admin-list.txt
which ps && ps aux | grep exporte[r] > ps_aux_grep_exporter.txt
which systemctl && systemctl status > systemctl_status.txt
which service && service --status-all > service_status.txt 2>&1

#todo: add support for QAN outputs needed

# Get all pmm-client logs
if [ -f /var/log/pmm-* ]
then
  tar czf var_log_pmm.tar.gz /var/log/pmm-*
fi

# Create .tar.gz file with outputs collected
# We were in pmm_client_collected, so we go back to the parent directory
cd ..
tar czf "pmm_client_summary.tar.gz" pmm_client_collected/*

# Delete temporary directories created
rm -rf pmm_server_collected
rm -rf pmm_client_collected


exit 0

