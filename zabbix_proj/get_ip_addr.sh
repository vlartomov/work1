#!/bin/bash
#the script prepares table with <<IPaddr and hostname>> for next script "zabbix-mass_stations.sh"
#then script "zabbix-mass_stations.sh" will build import ".xml" file for zabbix 

server_name=$(awk -F " " '{print $1}' postman_data.txt)

#getting hostnme and IP addres
function get_ip_and_hostname() {
 rm -f ip_of_serv.txt 
  for serv in ${server_name}; do
    ping -c3 ${serv} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -n "${serv} " >> ip_of_serv.txt
      ping -c1 ${serv} | awk '/'"64 bytes"'/{print $5}' | sed 's/^(//' | sed 's/.$//' | sed 's/.$//' >> ip_of_serv.txt
    else
      ping -c3 ${serv}".swx" > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo -n "${serv} " >> ip_of_serv.txt
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

#sort servers according to rack number
#function raks_order() {
#  while IFS= read -r line  
#  do
#    echo "$line" > /dev/null 2>&1 # 10.209.44.80 AGX-1
#    var3=$(echo "$line" | awk -F " " '{print $2}') # AGX-1
#    while IFS= read -r line1
#    do
#      echo "$line1" > /dev/null 2>&1 # AGX-1 8.1
#      var4=$(echo "$line1" | awk -F " " '{print $1}') # AGX-1
#      if [ "${var3}" == "${var4}" ]; then
#	var5=$(echo "$line1" | awk -F " " '{print $2}')
#        echo "${line} ${var5}"
#      fi
#    done < postman_data.txt
#  done < Bristol.txt 
#
#}
function find_unavailable_servers() {
  FILENAME="ip_of_serv.txt"
  rm -fR unavailable_servers.txt
  while IFS= read -r line
    do
      if [[ "$line" == *"not_accessible"* ]]; then
        echo "$line" >> unavailable_servers.txt
      fi
  done < ${FILENAME}
}

echo "$(output_ip_hostname)" > Bristol.txt
cat Bristol.txt  | sort | uniq | sed '/^$/d' > uniq_servers.txt
echo "$(find_unavailable_servers)"