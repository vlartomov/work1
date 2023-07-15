#!/bin/bash

set -xvEe -o pipefail

HNAME=$1

function modules_for_hpc(){
  sshpass -p 3tango ssh root@$HNAME 'sudo apt install -y environment-modules'
  new_row="/hpc/local/etc/modulefiles                              # hpcx modules "
  sshpass -p '3tango' ssh -t root@$HNAME << EOF
      echo "$new_row" | sudo tee -a /etc/environment-modules/modulespath >/dev/null
EOF
}

modules_for_hpc
