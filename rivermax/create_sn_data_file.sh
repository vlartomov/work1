#!/bin/bash

srv_list=$(cat list1.txt)

function check_xavier() {
  ssh_output=$(sshpass -p 3tango ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null rivermax@${srv} \
    "echo '3tango' | sudo -S mst cable add 2>/dev/null && echo '3tango' \
     | sudo -S mlxcables 2>/dev/null | awk '/"Serial number"/{print \$4}'")

  # Filter out unwanted lines
  ssh_output=$(echo -e "$ssh_output" | grep 'MT')

  # Format the output
  if [[ $? -eq 0 && -n "$ssh_output" ]]; then
    formatted_output_xavier=$(echo -e "$ssh_output" | tr -d '\r' | tr '\n' ',' | sed 's/,$//')
    formatted_output_xavier=$(echo "$formatted_output_xavier" | sed "s/,/','/g")
    formatted_output_xavier="['$formatted_output_xavier']"

    echo -n "${srv}: "
    echo "$formatted_output_xavier"
  fi
}

function check_mst(){
  for srv in ${srv_list}; do
    echo "${srv}"
    timeout 9s sshpass -p 3tango ssh root@${srv} 'mst status' 2>/dev/null
    if [ $? != 0 ]; then
      sshpass -p 3tango ssh root@${srv} 'apt-get install -y dkms' 2>/dev/null
      sshpass -p 3tango ssh root@${srv} '/auto/mswg/release/mft/mftinstall' 2>/dev/null
    else
      echo "."
    fi
  done
  echo "done"
}

function activate_mst(){
  for srv in ${srv_list}; do
    timeout 9s sshpass -p 3tango ssh root@${srv} 'mst start' >/dev/null
    status1=$? # Store exit status immediately after sshpass command
    timeout 9s sshpass -p 3tango ssh root@${srv} 'mst cable add' >/dev/null
    status2=$? # Store exit status immediately after sshpass command

    # Check the stored exit statuses
    if [ $status1 != 0 ] && [[ $srv == *"xavier"* || $srv == *"orin"* ]]; then
      check_xavier
    elif [ $status1 != 0 ] || [ $status2 != 0 ]; then
      output=$(sshpass -p admin ssh admin@${srv} cli \"enable\" \"show interfaces ethernet transceiver brief\" 2>/dev/null | awk '$NF!="N" && NF>1 {print $(NF-1)}')
      formatted_output=$(echo "$output" | awk '{printf "\x27%s\x27, ", $0}' | sed 's/, $//')
      formatted_output="[$formatted_output]"
      echo -n "${srv}: "
      echo "$formatted_output"

    else
      output2=$(sshpass -p 3tango ssh root@${srv} 'mlxcables' 2>/dev/null | awk '/'"Serial number"'/{print $4}')
      formatted_output_of_servers_and_cumulus=$(echo "$output2" | awk '{printf "\x27%s\x27, ", $0}' | sed 's/, $//')
      formatted_output_of_servers_and_cumulus="[$formatted_output_of_servers_and_cumulus]"
      echo -n "${srv}: "
      echo "$formatted_output_of_servers_and_cumulus"
    fi
  done
}

check_mst > /root/work1/rivermax/mst_log.txt
activate_mst > /root/work1/rivermax/sn_data.txt

