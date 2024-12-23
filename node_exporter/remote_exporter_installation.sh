#!/bin/bash

# Define the path to the uniq_servers.txt file
servers_file="uniq_servers.txt"

# Define the local path to the script to be copied
local_script_path="./node_exporter_installation_v2.sh"

# Check if the script exists locally
if [[ ! -f $local_script_path ]]; then
  echo "Error: Local script $local_script_path does not exist. Exiting."
  exit 1
fi

# Read the uniq_servers.txt file into an array
mapfile -t server_lines < "$servers_file"

# Loop through each line in the file
for line in "${server_lines[@]}"; do
  # Skip empty lines
  [[ -z $line ]] && continue

  # Extract the IP address and hostname from the line
  ip_address=$(echo "$line" | awk '{print $1}')
  server=$(echo "$line" | awk '{print $2}')
  
  # Define the full SSH connection string
  host="root@$server"
  echo "Processing $host"
  
  # Check the OS type on the server
  os_type=$(sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$host" \
    "cat /etc/os-release | grep '^ID=' | cut -d= -f2 | tr -d '\"'" 2>/dev/null)

  if [[ "$os_type" != "rhel" && "$os_type" != "ubuntu" ]]; then
    echo "Skipping $host: Unsupported OS ($os_type)"
    continue
  fi

  # Check if Node Exporter is already installed
  node_exporter_status=$(sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$host" \
    "node_exporter --version 2>/dev/null")
  if [[ $? -eq 0 ]]; then
    echo "Node Exporter is already installed on $host."
    continue
  fi

  # Copy the script to the remote server
  sshpass -p 3tango scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$local_script_path" "$host:/tmp/"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy $local_script_path to $host:/tmp/. Skipping."
    continue
  fi
  
  # Execute the script on the remote server
  sshpass -p 3tango ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$host" \
    "/tmp/node_exporter_installation_v2.sh"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute /tmp/node_exporter_installation_v2.sh on $host. Skipping."
    continue
  fi

done

