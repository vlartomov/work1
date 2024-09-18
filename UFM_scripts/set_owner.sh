#!/bin/bash

# Temporary file to store the updated content
temp_file=$(mktemp)

# Ensure the temporary file gets deleted on exit
trap 'rm -f "$temp_file"' EXIT

# Read each line from postman_data.txt
while IFS=' ' read -r host_owner data; do
  # Check if the host_owner exists in outputfile_3.txt
  grep -q " $host_owner" outputfile_3.txt
  if [ $? -eq 0 ]; then
    # If found, append the additional data to the line in outputfile_3.txt
    awk -v host="$host_owner" -v info="$data" '{if ($2 == host) print $0, info; else print $0}' outputfile_3.txt > "$temp_file" && mv "$temp_file" outputfile_3.txt
  fi
done < postman_data.txt
