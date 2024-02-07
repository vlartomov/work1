#!/bin/bash
## The script returns the SETUP number and hostname
srv=$(awk -F " " '{print $1}' list.txt)

# Initialize a counter for the setup number
setup_counter=1

# Initialize an associative array to keep track of devices and their respective setup numbers
declare -A device_setup_map

for serv in ${srv}; do
  # Ping check
  ping -c 1 "$serv" &>/dev/null
  if [ $? -ne 0 ]; then
    continue  # Skip the rest of the loop and proceed with the next server
  fi

  # Fetch device list from the server
  devices=$(sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"${serv}" ibhosts 2>/dev/null | awk -F\" '$2 != "Mellanox Technologies Aggregation Node" {print $2}' | awk '{print $1}')

  # Check if "devices" is empty or contains error message
  if [ -z "$devices" ]; then
#    echo "No valid devices found for $serv or there was an error."
    continue  # Skip to the next server
  fi

  # Initialize a variable to determine if a new setup is needed
  new_setup_needed=true
  setup_number=""

  for dev in ${devices}; do
    # If the device is already assigned a setup, use that setup number
    if [[ -n ${device_setup_map[$dev]} ]]; then
      setup_number=${device_setup_map[$dev]}
      new_setup_needed=false
      break # No need to check other devices as one is found in an existing setup
    fi
  done

  # If none of the devices are in an existing setup, assign a new setup number
  if $new_setup_needed; then
    setup_number=$setup_counter
    # Assign all devices from the current server to the new setup number
    for dev in ${devices}; do
      device_setup_map[$dev]=$setup_number
    done
    setup_counter=$((setup_counter+1)) # Increment the setup counter for the next new server
  fi

  for i in ${devices}; do
    echo "setup_${setup_number}   ${i}"
  done
  ib_sw=$(sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"${serv}" ibswitches 2>/dev/null | awk -F\" '!/Mellanox/ {print $2}' | sed 's/:.*$//' | sed 's/^.*;//')
  for x in ${ib_sw}; do
    echo "setup_${setup_number}   ${x}"
  done
done

