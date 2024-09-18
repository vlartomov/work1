#!/bin/bash

array_serv=("elsa02" "elsa03" "elsa04" "elsa05" "elsa06" "elsa07" "elsa08")

sshp_t_srv="sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"

for srv in ${array_serv[@]}; do
  ssh_cmd="${sshp_t_srv}${srv}"
  $ssh_cmd "sed -i '/fi/{:a;n;/alias lshca=sudo \/hpc\/local\/bin\/lshca/d}' ~/.bashrc"
  echo "Removed alias from $srv"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
done

