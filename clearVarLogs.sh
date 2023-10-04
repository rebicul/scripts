#!/bin/bash

# Find large log files and store their paths into an array
log_files=($(find /var/log -type f -size +50M ! -name 'lastlog' -print0 | xargs -0))

# Loop through the array and process each log file
for logfile in "${log_files[@]}"; do

    # Calculate the number of lines to keep last 100 lines
    lines_to_keep=$(( $(wc -l < "$logfile") - 100 ) )

    # Use sed to edit the file in place and keep the last 100 lines
    sed -i "1,${lines_to_keep}d" "$logfile"

done