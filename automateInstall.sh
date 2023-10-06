#!/bin/bash

# Grab the name of the user's directory and store the path into a variable
session_usr_dir=$(pwd)
echo "Hello $(echo "$session_usr_dir" | sed 's#.*/##')"

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
    
    # Find and store the paths of files that match the criteria
    files_to_move=()
    while IFS= read -r file; do
        files_to_move+=("$file")
    done < <(find /var/log -type f -size +50M -mtime +0 ! -name 'lastlog' -exec ls -S {} +)

    # Determine how many files to move (up to a maximum of 3)
    num_to_move="${#files_to_move[@]}"
    if [ "$num_to_move" -gt 3 ]; then
        num_to_move=3
    fi

    # Move the selected files to the $session_usr_dir home directory
    for ((i = 0; i < num_to_move; i++)); do
        file="${files_to_move[$i]}"
        mv "$file" "$session_usr_dir/"
    done

    # Run clearVarLogs.sh located in /usr/local/bin/scripts
    if [ -f "/usr/local/bin/scripts/clearVarLogs.sh" ]; then
        /usr/local/bin/scripts/clearVarLogs.sh
    else
        echo "clearVarLogs.sh not found in /usr/local/bin/scripts."
        exit 1
    fi

    # Move the files back to their previous directories
    for ((i = 0; i < num_to_move; i++)); do
        file="${files_to_move[$i]}"
        mv "$session_usr_dir/$(basename "$file")" "$(dirname "$file")/"
    done

    # Run clearVarLogs.sh again to modify files that were not in the /var/log previously
    if [ -f "/usr/local/bin/scripts/clearVarLogs.sh" ]; then
        /usr/local/bin/scripts/clearVarLogs.sh
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

# Self-deleting shell script
echo "Self deleting automateInstall.sh..."
rm -- "$0"