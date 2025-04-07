#!/bin/bash

HOSTNAME=$(hostname)
CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | xargs)
RAM=$(free -h | awk '/Mem:/ {print $2}')
VAULT_SIZE=$(df -h | grep '/vault' | awk '{print $3 " used / " $2 " total"}')

echo " "
echo "HOSTNAME: $HOSTNAME"
echo "CPU: $CPU"
echo "RAM: $RAM"
echo "/vault size: $VAULT_SIZE"
echo " "