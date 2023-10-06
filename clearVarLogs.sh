#!/bin/bash

# Find large log files and store their paths into an array
log_files=($(find /var/log -type f -size +50M ! -name 'lastlog' -print0 | xargs -0))

# Loop through the array and process each log file
for logfile in "${log_files[@]}"; do

    # Calculate the number of lines in the file
    total_lines=$(wc -l < "$logfile")

    # Calculate the number of lines to keep (last 100 lines)
    lines_to_keep=$(( total_lines - 100 ))

    # Check if lines_to_keep is non-negative to avoid errors
    if [ "$lines_to_keep" -ge 0 ]; then
        # Use sed to edit the file in place and keep the last 100 lines
        sed -i "1,${lines_to_keep}d" "$logfile"
    else
        echo "File $logfile has fewer than 100 lines. Skipping..."
    fi

done