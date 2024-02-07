#!/bin/bash
srv_list=$(cat list_of_pdu.txt)
for srv in ${srv_list}; do
  HOSTNAME=$(nslookup ${srv} | awk '/name =/ {print $4}' | sed 's/\..*//')
#  if [ ! -z "$HOSTNAME" ]; then
  echo " ${srv}  $HOSTNAME swx"
#  fi
done

