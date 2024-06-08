# ssClean.sh -L

This script (ssClean.sh) with option (-L) is designed to clean null (^@) characters from specified Docker container logs.

## Steps to Run
1. **find container name**: find the docker container name for which log files are corrupted
    ```
    sudo docker ps
    ```

2. **Run the Script**: Execute the docker_log_repair.sh script to repair Docker error logs (Error grabbing logs: invalid character '\x00' looking for beginning of value
).When prompted provide the docker name for which docker logs are corrupted (as found in step 1)

    ```
    sudo bash <path_to_file>/ssClean.sh -L ods

    Example:ubuntu2:~$ sudo bash ~/MTConnect_SmartSaw/ssClean.sh -L ods
    ```
     Docker log will be repaird with the same file name.
