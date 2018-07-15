#!/bin/bash

### PMM-SERVER OUTPUTS COLLECTION ###
echo "Gathering outputs from PMM server..."

if [ -d pmm_server_collected ]
then
  echo "ERROR: pmm_server_collected directory should not be created."
  echo "Aborting execution."
  exit 1
fi

mkdir pmm_server_collected 2>/dev/null
cd pmm_server_collected

# Check if there is a docker pmm-server container running
docker container ls -a --filter name="^/pmm-server$" 2>/dev/null | grep pmm-server >/dev/null 2>&1

# if there is a pmm-server docker container (uses return code from previous command)
if [ $? -eq 0 ]
then
  # Collect information from Docker outputs

  # Docker-specific outputs
  docker container inspect pmm-data > docker_inspect_pmm-data.txt
  docker container inspect pmm-server > docker_inspect_pmm-server.txt
  docker container logs pmm-data > docker_logs_pmm-data.txt
  docker container logs pmm-server > docker_logs_pmm-server.txt
  docker --version > docker_version.txt
  docker container ls -a > docker_ls-a.txt

  docker container ls --filter name="^/pmm-server$" --filter status=running 2>/dev/null | grep pmm-server >/dev/null 2>&1

  # if the pmm-server container is running (uses return code from previous command)
  if [ $? -eq 0 ]
  then
    docker container exec pmm-server supervisorctl status > docker_supervisorctl-status.txt
    docker container exec pmm-server find / -name \*VERSION -exec echo {} \; -exec cat {} \; > docker_find_version.txt
    docker container exec pmm-server cat /etc/prometheus.yml > docker_cat_etc-prometheus.txt
    docker container exec pmm-server cat /etc/supervisord.d/pmm.ini > docker_cat_etc-supervisord-pmm.txt
    docker container exec pmm-server cat /etc/nginx/conf.d/pmm.conf > docker_cat_etc-nginx-pmm.txt

    # Get all logs
    docker container cp pmm-server:/var/log/ - | gzip - > var_log.gz
  fi

else
  # if there is no pmm-server docker container running, we assume we are running in a non-dockerized deployment

  #todo: only get supervisorctl?
  supervisorctl status > supervisorctl-status.txt
  # todo: change find command for something else, since it can be expensive
 # find / -name \*VERSION -exec echo {} \; -exec cat {} \; 2>/dev/null > find_version.txt
  cat /etc/prometheus.yml > cat_etc-prometheus.txt
  cat /etc/supervisord.d/pmm.ini > cat_etc-supervisord-pmm.txt
  cat /etc/nginx/conf.d/pmm.conf > cat_etc-nginx-pmm.txt

  # Get all logs
  tar czf var_log.tar.gz /var/log/*
fi

# Finally, collect outputs common to all deployments
pt-summary --sleep=1 > pt-summary.txt

# Get credentials and IP address/port for curl commands
PMM_USER=`grep username *cat_etc-prometheus.txt | awk {'print $2'} | head -n1`
PMM_PASSWORD=`grep password *cat_etc-prometheus.txt | awk {'print $2'} | head -n1`
# to support the URL (for curl commands) where user and pass are empty
if [ "${PMM_PASSWORD}" != "" ]; then PMM_PASSWORD=":"${PMM_PASSWORD}"@"; fi
PMM_IP_ADDR='127.0.0.1'
PMM_PORT=`grep listen *cat_etc-nginx-pmm.txt | awk {'print $2'} | tr -d ';' | head -n1`

# Get outputs from
curl -s "http://${PMM_USER}${PMM_PASSWORD}${PMM_IP_ADDR}:${PMM_PORT}/prometheus/targets" > curl_prometheus.out
curl -s "http://${PMM_USER}${PMM_PASSWORD}${PMM_IP_ADDR}:${PMM_PORT}/v1/internal/ui/nodes?dc=dc1" > curl_consul-metrics.txt
curl -s "http://${PMM_USER}${PMM_PASSWORD}${PMM_IP_ADDR}:${PMM_PORT}/qan-api/instances" > curl_qan.txt

# Create .tar.gz file with outputs collected
# We were in pmm_server_collected, so we go back to the parent directory
cd ..
tar czf "pmm_server_summary.tar.gz" pmm_server_collected/*


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
