#!/bin/bash -Ee

#set -eEvx
#set -o pipefail

# The script fetches the server name based on a Zabbix trigger.
# If the server is not reachable via ping, it initiates a power cycle command; otherwise, it halts script execution.

# Check if the provided argument is pingable
if ping -c 2 "$1" &> /dev/null; then
  echo "Host $1 is reachable. Exiting..."
  exit 0
fi

# Function to search for the service
function search_service() {
  # Check if the correct number of arguments are provided
  if [ $# -ne 1 ]; then
    echo "Usage: search_service <search_term>"
    return 1
  fi
    local serv="$1"
  timeout 10s awk -v search="$serv" 'tolower($0) ~ tolower(search) {sub(/;$/, "", $3); print $3}' /.autodirect/LIT/SCRIPTS/DHCPD/list
  if [ $? -eq 124 ]; then
    echo "search_service timed out after 30 seconds."
  fi
}

srv=$(search_service "$1")

if [ -z "$srv" ]; then
#  echo "No matching service found. Exiting."
  srv=$(dig -x $1 +short | awk -F'.' '{print $1}')
  ip_of_ilo=$(ping -c 1 $srv-ilo | grep -oP '(\d+\.\d+\.\d+\.\d+)' | head -n 1)
  ipmitool -I lanplus -H $ip_of_ilo -U root -P 3tango11 power cycle 
fi


output=$(timeout 10s grep -i "${srv}-ilo" /.autodirect/LIT/SCRIPTS/DHCPD/list)

# Extract the IP if the result is not empty
if [ -n "$output" ]; then
  result=$(echo "$output" | awk '{ print $1; exit }' | sed 's/;$//')
  ipmitool -I lanplus -H $result -U root -P 3tango11 power cycle
#  echo "$result"
else
  echo "Looks like ${srv} doesn't have the IPMI in our DHCP"
fi
