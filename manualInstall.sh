#!/bin/bash

# Get the current user's directory
session_usr_dir=$(pwd)
user_name=$(basename "$session_usr_dir")
echo "Hello $user_name"

# Check and create 'scripts' folder if it doesn't exist
scripts_dir="/usr/local/bin/scripts"
if [ -d "$scripts_dir" ]; then
    echo "'scripts' folder exists."
else
    echo "'scripts' folder does not exist, creating it..."
    mkdir -p "$scripts_dir"
fi


# Store the code in the raw_code variable
raw_code='#!/bin/bash

# Find large log files and store their paths into an array
log_files=($(find /var/log -type f -size +50M ! -name "lastlog" -print0 | xargs -0))

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
done'

# Check if clearVarLogs.sh already exists
if [ -f "$scripts_dir/clearVarLogs.sh" ]; then
    echo "clearVarLogs.sh already exists in $scripts_dir. Skipping file creation."

    # Check if the file is executable
    if [ -x "$scripts_dir/clearVarLogs.sh" ]; then
        echo "clearVarLogs.sh is executable."
    else
        echo "clearVarLogs.sh is not executable. Making it executable..."
        chmod +x "$scripts_dir/clearVarLogs.sh"
    fi
else
    # Create the clearVarLogs.sh file with raw_code
    echo "$raw_code" > "$scripts_dir/clearVarLogs.sh"
    chmod +x "$scripts_dir/clearVarLogs.sh"
fi

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

# Define the threshold
threshold=97

# Check if usage is above the threshold
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

    ls -lh

    # Move the selected files to the $session_usr_dir home directory
    for ((i = 0; i < num_to_move; i++)); do
        file="${files_to_move[$i]}"
        mv "$file" "$session_usr_dir/"
    done

    ls -lh

    # Run clearVarLogs.sh
    if [ -f "$scripts_dir/clearVarLogs.sh" ]; then
        "$scripts_dir/clearVarLogs.sh"
    else
        echo "clearVarLogs.sh not found in $scripts_dir."
        exit 1
    fi

    # Move the files back to their previous directories
    for ((i = 0; i < num_to_move; i++)); do
        file="${files_to_move[$i]}"
        mv "$session_usr_dir/$(basename "$file")" "$(dirname "$file")/"
    done

    ls -lh

    # Run clearVarLogs.sh again
    if [ -f "$scripts_dir/clearVarLogs.sh" ]; then
        "$scripts_dir/clearVarLogs.sh"
    else
        echo "clearVarLogs.sh not found in $scripts_dir."
        exit 1
    fi

    echo "Operation completed."
else
    echo "Disk usage for /var is less than $threshold%. Running clearVarLogs.sh now..."

    # Run clearVarLogs.sh
    if [ -f "$scripts_dir/clearVarLogs.sh" ]; then
        "$scripts_dir/clearVarLogs.sh"
    else
        echo "clearVarLogs.sh not found in $scripts_dir."
        exit 1
    fi

    echo "Operation completed."
fi

cron_job="0 18 * * 0 $scripts_dir/clearVarLogs.sh"

# Check if the cron job already exists in the crontab
if (crontab -l | grep -Fxq "$cron_job"); then
    echo "Cron job already exists."
else
    # Add the cron job to the crontab
    (crontab -l ; echo "$cron_job") | crontab -
    echo "Cron job added to run clearVarLogs.sh on Sundays at 6 p.m."
fi

# Self-delete the script
echo "Self-deleting $(basename "$0")..."
rm -- "$0"