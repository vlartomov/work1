#!/bin/bash
srv_list=$(cat list1)
for srv in ${srv_list}; do
  echo "${srv}" 
  output=$(sshpass -p 3tango ssh root@"${srv}" df --total /var/lib/docker | awk '/\// {print $4}')
  echo "${output}"
  echo "========================"
done
