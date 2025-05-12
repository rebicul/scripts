#!/bin/bash

# Get df -h header
VAULT_HEADER=$(df -h | head -n 1)

# Get the /vault line (if it exists)
VAULT_LINE=$(df -h | awk '$NF == "/vault"')

# Output
echo ""
if [ -n "$VAULT_LINE" ]; then
    echo "$VAULT_HEADER"
    echo "$VAULT_LINE"
else
    echo "/vault not found in df -h output"
fi
echo ""
