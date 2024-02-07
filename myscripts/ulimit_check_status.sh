#!/bin/bash
srv_list=$(awk -F " " '{print $1}' rock_list.txt)
for srv in  ${srv_list}; do
  echo "${srv}"
  sshpass -p 3tango ssh root@${srv} 'ulimit -l'
done

