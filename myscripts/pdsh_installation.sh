#!/bin/bash

#array_serv=("elsa03" "elsa04")
array_serv=("elsa01" "elsa03" "elsa04" "elsa05" "elsa06" "elsa07" "elsa08")

sshp_t_srv="sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"

for srv in ${array_serv[@]}; do
  pdsh_inst=$( ${sshp_t_srv}${srv} "yum install -y pdsh-rcmd-ssh.x86_64" )
  pdsh_activation=$( ${sshp_t_srv}${srv} "export PDSH_RCMD_TYPE=ssh" )
  echo "${srv}"
  echo "${pdsh_inst}"
  echo "${pdsh_activation}"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

