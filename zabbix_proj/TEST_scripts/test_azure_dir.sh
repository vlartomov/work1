#!/bin/bash
srv_list=$(cat list1)
for srv in ${srv_list}; do
  echo "${srv}" 
  output=$(sshpass -p 3tango ssh root@"${srv}" du -shx /labhome/swx-azure-svc 2>/dev/null | awk '{print $1}' | grep -o '[0-9]*')
  echo "${output}"
  echo "========================"
done
