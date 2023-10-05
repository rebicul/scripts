#!/bin/bash

# Check if 'scripts' folder exists in /usr/local/bin directory
if [ -d "/usr/local/bin/scripts" ]; then
    echo "'scripts' folder exists, changing directory to it..."
    cd /usr/local/bin/scripts
else
    echo "'scripts' folder does not exist, creating it..."
    mkdir /usr/local/bin/scripts
    cd /usr/local/bin/scripts
fi

# cURL raw clearVarLogs.sh from GitHub repo and make it executable
curl -O 'URL'
chmod +x clearVarLogs.sh

# Run df -h and grep for "/var/*"
df_output=$(df -h | grep "/var/*")

# Count the number of lines in the output
line_count=$(echo "$df_output" | wc -l)

if [ "$line_count" -gt 1 ]; then
    # If more than one line is returned, find the line with "/var/log" and grab its usage
    var_usage=$(echo "$df_output" | grep "/var/log$" | awk '{print $5}' | sed 's/%//')
    echo "Disk usage for /var/log is $var_log_usage%."
else
    # If only one line is returned, get the usage for /var
    var_usage=$(echo "$df_output" | awk '{print $5}' | sed 's/%//')
    echo "Disk usage for /var is $var_usage%."
fi

threshold=97

if [ "$var_usage" -ge "$threshold" ]; then
    echo "Disk usage for /var is above the threshold of $threshold%. Moving a few files into your home directory."
    
    # Prompt the user for their username
    read -p "Enter your username (firstname.lastname): " username

    # Validate that the username is not empty
    if [ -z "$username" ]; then
        echo "Username cannot be empty. Exiting."
        exit 1
    fi

    # Find files greater than 50M sorted in descending order in /var/log that haven't been modified today.
    files_to_move=$(find /var/log -type f -size +50M -mtime +0 ! -name 'lastlog' -exec ls -lSh {} +)
    
    # Create an associative array to store original paths
    declare -A original_paths

    # Get the first two files from the sorted list and store their original paths
    first_two_files=$(echo "$files_to_move" | head -n 2)
    while read -r file; do
        original_paths["$file"]=$(dirname "$file")
    done <<< "$first_two_files"

    # Run clearVarLogs.sh located in /usr/local/bin/scripts
    if [ -f "/usr/local/bin/scripts/clearVarLogs.sh" ]; then
        ./usr/local/bin/scripts/clearVarLogs.sh
    else
        echo "clearVarLogs.sh not found in /usr/local/bin/scripts."
        exit 1
    fi

    # Move the first two files back to their original directories
    for file in "${!original_paths[@]}"; do
        original_dir="${original_paths[$file]}"
        mv "$file" "$original_dir/"
    done

    # Run clearVarLogs.sh again to modify files that were not in the /var/log previously
    if [ -f "/usr/local/bin/scripts/clearVarLogs.sh" ]; then
        ./usr/local/bin/scripts/clearVarLogs.sh
    else
        echo "clearVarLogs.sh not found in /usr/local/bin/scripts."
        exit 1
    fi

    echo "Operation completed."

else
    echo "Disk usage for /var is within the threshold of $threshold%. Running the script now..."
    
    # Run clearVarLogs.sh located in /usr/local/bin/scripts
    if [ -f "/usr/local/bin/scripts/clearVarLogs.sh" ]; then
        /usr/local/bin/scripts/clearVarLogs.sh
    else
        echo "clearVarLogs.sh not found in /usr/local/bin/scripts."
        exit 1
    fi

    echo "Operation completed."

fi

# Create a cron job to run the script on Sundays at 6 p.m.
(crontab -l ; echo "0 18 * * 0 /usr/local/bin/scripts/clearVarLogs.sh") | crontab -
echo "Cron job added to run clearVarLogs.sh on Sundays at 6 p.m."