#!/bin/bash

# Capture df -h header and /vault line
VAULT_HEADER=$(df -h | head -n 1)
VAULT_LINE=$(df -h | grep '/vault')

echo " "

if [ -n "$VAULT_LINE" ]; then
    echo "$VAULT_HEADER"
    echo "$VAULT_LINE"
else
    echo "/vault not found in df -h output"
fi

echo " "
