#!/bin/bash

# Input file
input_file="uniq_servers.txt"

# Output file
output_file="values.txt"

# Ensure the input file exists
if [[ ! -f $input_file ]]; then
  echo "Error: Input file $input_file not found."
  exit 1
fi

# Clear or create the output file
> "$output_file"

# Process each line in the input file
while IFS= read -r line || [[ -n $line ]]; do
  # Skip empty lines
  [[ -z $line ]] && continue

  # Extract the hostname from the line (second column)
  hostname=$(echo "$line" | awk '{print $2}')
  
  # Format and append to the output file
  echo "- '${hostname}.mtr.labs.mlnx:9100'" >> "$output_file"
done < "$input_file"

echo "Output written to $output_file"

