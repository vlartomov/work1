#!/bin/bash

#array_serv=("elsa03" "elsa04")
#array_serv=("elsa02" "elsa03" "elsa04" "elsa05" "elsa06" "elsa07" "elsa08")
array_serv=(nemo{01..08})

sshp_t_srv="sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"

for srv in ${array_serv[@]}; do
  add_module=$(${sshp_t_srv}${srv} 'echo "/hpc/local/etc/modulefiles                              # hpcx modules" >> /etc/environment-modules/modulespath')
  inst_modules=$(${sshp_t_srv}${srv} 'sudo yum install -y environment-modules')
  set_lshca=$( ${sshp_t_srv}${srv} "sed -i \"/# Source global definitions/i alias lshca='sudo /hpc/local/bin/lshca'\" ~/.bashrc" )
  echo "${set_lshca}"
  echo "${inst_modules}"
  echo "${add_module}"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

