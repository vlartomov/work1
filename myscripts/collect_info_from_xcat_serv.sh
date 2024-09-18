#!/bin/bash

#array_serv=("nemo01" "nemo02" "03" "elsa04" "elsa05" "elsa06" "elsa07" "elsa08")
array_serv=(ajna{01..08})
sshp_t_srv="sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"


for srv in ${array_serv[@]}; do
  mgmt=$(${sshp_t_srv}${srv} 'ip add | grep -A 1 'eno1'')
  ipmi=$(${sshp_t_srv}${srv} 'ipmitool lan print | grep -A 2 "IP Address"')
  echo "${srv}"
  echo "${mgmt}"
  echo "                             ipmi part                           "
  echo "${ipmi}"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

