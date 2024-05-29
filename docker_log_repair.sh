#!/bin/bash

# Prompt the user for the container name
read -p "Enter the Docker container name: " container_name
echo " "
# Get the log path for the specified container
log_path=$(docker inspect --format='{{.LogPath}}' "$container_name")

# Check if the log path was successfully retrieved
if [ -z "$log_path" ]; then
    echo "Failed to retrieve log path for container $container_name"
    exit 1
fi
echo "Log path for container $container_name: $log_path"
echo " "

# Extract the file name and directory of the log file
log_dir=$(dirname "$log_path")
log_file=$(basename "$log_path")

# Remove null characters from the log file and its rotated versions
for logs in "$log_dir/$log_file"*; 
do
    if [ -e "$logs" ]; then
        sed -i 's/\x00//g' "$logs"
        echo " "
        echo "Null characters removed. Repair successful."
        echo "Repaired log file at $logs"
    fi
done

