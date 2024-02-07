#!/bin/bash
srv_list=$(cat list1)
for srv in ${srv_list}; do
  echo "${srv}" 
  output=$(sshpass -p 3tango ssh root@"${srv}" df --total /scrap | awk '($NF=="/scrap" || $NF=="/") && !seen[$NF]++ {print $4}')
  echo "${output}"
  echo "========================"
done
