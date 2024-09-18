#!/bin/bash

# Define the input file
input_file="outputfile_3.txt" # Replace this with the path to your actual input file
output_file="formatted_output_with_tabs.txt" # This is where the output will be saved

# Use awk to insert three tabs after the $2 value
awk '{
    # Print $1, then a tab, then $2
    printf "%s\t%s", $1, $2;
    # Then print three tabs
    printf "\t\t\t\t\t";
    # Now print the rest of the line starting from field 3
    for (i=3; i<=NF; i++) printf "%s ", $i;
    printf "\n"
}' "$input_file" > "$output_file"

echo "Formatting complete. Output saved to $output_file."


