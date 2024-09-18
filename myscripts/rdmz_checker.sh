#!/bin/bash
srv_list=$(awk -F " " '{print $1}' temp_file.txt)
for srv in ${srv_list}; do
  echo "=================== ${srv}====================="
  sshpass -p 3tango ssh root@${srv} 'for iface in $(ibstat -l | awk '\''{print $1}'\''); do if ibstat $iface | grep -q "State: Down"; then echo "Interface $iface is Down"; fi; done'
  echo "==============================================="
done

