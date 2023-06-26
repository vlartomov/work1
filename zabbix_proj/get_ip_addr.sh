#!/bin/bash
#the script prepares table with <<IPaddr and hostname>> for next script "zabbix-mass_stations.sh"
#then script "zabbix-mass_stations.sh" will build import ".xml" file for zabbix 

path_z="/root/work1/zabbix_proj"
server_name=$(awk -F " " '{print $1}' /root/work1/zabbix_proj/postman_data.txt)

#getting hostnme and IP addres
function get_ip_and_hostname() {
 rm -f /root/work1/zabbix_proj/ip_of_serv.txt 
  for serv in ${server_name}; do
    ping -c3 ${serv} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -n "${serv} " >> /root/work1/zabbix_proj/ip_of_serv.txt
      ping -c1 ${serv} | awk '/'"64 bytes"'/{print $5}' | sed 's/^(//' | sed 's/.$//' | sed 's/.$//' >> /root/work1/zabbix_proj/ip_of_serv.txt
    else
      ping -c3 ${serv}".swx" > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo -n "${serv} " >> /root/work1/zabbix_proj/ip_of_serv.txt
        ping -c1 ${serv}".swx" | awk '/'"64 bytes"'/{print $5}' | sed 's/^(//' | sed 's/.$//' | sed 's/.$//' >> ip_of_serv.txt
      else
        echo "${serv} not_accessible" >> ip_of_serv.txt
      fi
    fi
  done
}

#replacing position of datas(IPaddr hostname)
function output_ip_hostname() {
  echo "$(get_ip_and_hostname)"
  out1=$(awk -F " " '{print $2,$1}' ip_of_serv.txt) # 10.209.44.80 AGX-1 
  out2=$(echo "${out1}" | awk '!/not/')
  echo "${out2}"
}

function find_unavailable_servers() {
  FILENAME="ip_of_serv.txt"
  rm -fR /root/work1/zabbix_proj/unavailable_servers.txt
  while IFS= read -r line
    do
      if [[ "$line" == *"not_accessible"* ]]; then
        echo "$line" >> /root/work1/zabbix_proj/unavailable_servers.txt
      fi
  done < ${FILENAME}
}

echo "$(output_ip_hostname)" > /root/work1/zabbix_proj/Bristol.txt
cat /root/work1/zabbix_proj/Bristol.txt  | sort | uniq | sed '/^$/d' > /root/work1/zabbix_proj/uniq_servers.txt
echo "$(find_unavailable_servers)"