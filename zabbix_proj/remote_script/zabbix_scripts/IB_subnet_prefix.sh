#!/bin/bash

# Remote host name
REMOTE_HOST="pjazz"

# File path on the remote host
FILE_PATH="/opt/ufm/files/conf/opensm/opensm.conf"

# Value to check
VALUE="fe81000000000000"

# Execute command remotely to check if the file exists and contains the value
ssh "$REMOTE_HOST" "
    if [[ -f '$FILE_PATH' ]]; then
        if grep -q '$VALUE' '$FILE_PATH'; then
            echo 'Value $VALUE found in $FILE_PATH.'
        else
            echo 'Error: Value $VALUE not found in $FILE_PATH.'
        fi
    else
        echo 'Error: File $FILE_PATH does not exist.'
    fi
"

