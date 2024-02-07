#!/bin/bash

srv_list=$(awk '{print $1}' list_of_servers.txt)

for srv in ${srv_list}; do
  echo "[${srv}]"
  sshpass -p 3tango ssh root@${srv} 'cat /etc/*release | grep "PRETTY_NAME="'
  sshpass -p 3tango ssh root@sputnik2 "systemctl status ypbind.service | awk '\$0 ~ /Active/ {print \$2}'"
  echo "================================================================"
done


