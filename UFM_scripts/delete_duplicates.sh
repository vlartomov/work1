#!/bin/bash

# Define the file containing the server list
input_file="outputfile_3.txt" # replace with your actual file path

# Temporary file to store unique lines
temp_file=$(mktemp)

# Associative array to hold the server names
declare -A server_names

# Read the file line by line
while IFS= read -r line; do
  # Extract the server name using awk
  server_name=$(echo "$line" | awk '{ print $2 }')
  
  # Check if the server name is already in the associative array
  if [[ -z "${server_names[$server_name]}" ]]; then
    # If not, add it to the array and write the line to the temp file
    server_names[$server_name]=1
    echo "$line" >> "$temp_file"
  fi
done < "$input_file"

# Move the temp file to the original file to overwrite it with the unique list
mv "$temp_file" "$input_file"

# Cleanup
unset server_names
rm -f "$temp_file"  # Optional, as temp file is already moved

echo "Duplicates removed, unique list saved to $input_file."
