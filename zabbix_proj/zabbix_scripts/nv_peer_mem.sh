#!/bin/bash

# The script fetches the server name based on a Zabbix trigger.
# If the server is reachable via ping, it initiates a disk check; otherwise, it halts script execution.

srv=${1}
echo "${srv}" > /root/work1/zabbix_proj/zabbix_scripts/server_name_from_zabbix.txt
server_name=$(grep -i "${srv}" /.autodirect/LIT/SCRIPTS/DHCPD/list | awk '{gsub(";", ""); print $3}')

# Check if a server name was provided as an argument
if [ -z "${srv}" ]; then
  echo "Error: No server name provided. Exiting..."
  exit 1
fi

# Check if the provided argument is pingable
if ping -c 1 "${srv}" &> /dev/null; then
  output=$(sshpass -p 3tango ssh root@"${srv}" systemctl status nv_peer_mem  | awk '$0 ~ /Active/ {print $2}')
  if [ "$output" != "active" ]; then
    /root/work1/zabbix_proj/zabbix_scripts/email_notificaition_test.sh "${srv}"
    sshpass -p 3tango ssh root@"${srv}" systemctl restart nv_peer_mem
  else
    exit 0
  fi
else
  exit 0
fi
