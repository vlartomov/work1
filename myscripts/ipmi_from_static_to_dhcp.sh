#!/bin/bash

#array_serv=("nemo01" "nemo02" "nemo03" "nemo04" "nemo05" "nemo06" "10.210.1.28" "10.210.1.30")
array_serv=(ajna{01..08})

sshp_t_srv="sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"

for srv in ${array_serv[@]}; do
  ipmi_to_dhcp=$(${sshp_t_srv}${srv} 'ipmitool lan set 1 ipsrc dhcp')
#  ipmi_reset=$(${sshp_t_srv}${srv} 'ipmitool power cycle')
  ipmi_lan_print=$(${sshp_t_srv}${srv} 'ipmitool lan print 1')
  echo "${srv}"
  echo "${ipmi_to_dhcp}"
  sleep 30
  echo "${ipmi_lan_print}"
#  echo "${ipmi_reset}"  
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

