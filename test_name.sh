#!/bin/bash

# Function to perform the "dhcp" command
function dhcp() {
  cat /.autodirect/LIT/SCRIPTS/DHCPD/list | grep -i "$1"
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

filename="$1"

# Check if the file exists and is readable
if [ ! -r "$filename" ]; then
  echo "Error: File '$filename' not found or not readable."
  exit 1
fi

# Read and execute each line from the file using the "dhcp" function
while IFS= read -r line; do
  dhcp "$line"
done < "$filename"


#srv_list=$(awk '{gsub(/;/,"");print $1}' list1.txt)
#for i in $srv_list; do
#  dhcp ${i}
#done




