#!/bin/bash

input_file="ipmi_list.txt"
output_file="ipmi_list_v2.txt"

# Empty the output file if it exists
> "$output_file"

while read -r line; do
    # Extract hostname from the line
    hostname=$(echo "$line" | awk '{print $2}')
    ipmi_host="${hostname}-ilo"

    # Get the IP address using ping
    ipmi_ip=$(ping -c 1 "$ipmi_host" | awk -F'[()]' '/PING/{print $2}')

    # Check if we got an IP
    if [[ -n "$ipmi_ip" ]]; then
        echo "$ipmi_host $ipmi_ip" >> "$output_file"
        echo "Resolved: $ipmi_host -> $ipmi_ip"
    else
        echo "Failed: $ipmi_host" >> "$output_file"
        echo "Failed to resolve: $ipmi_host"
    fi
done < "$input_file"

echo "New IPMI list saved to $output_file"

