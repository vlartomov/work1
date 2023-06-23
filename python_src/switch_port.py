#!/usr/src/Python-3.7.7/python
import os 
import subprocess
import time
import sys, os

#s4itivaem hostname
def srv_name():
  hn = raw_input("enter hostname: ")
  print('=====================')
  print(hn)

def activate_mst():
  srv_name()
  print('=====================')
#  cmd = 'mst start'
#  subprocess.Popen("ssh {user}@{host} {cmd}".format(user=root, host=srv_name(), cmd='mst start'), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
#  retrocode = subprocess.call(cmd, shell=True)
#  os.system('sshpass -p '3tango ssh' root@srv_name() 'mst start'')
# ("sshpass -p 3tango ssh root@srv_name() mst cable add")
#  shell = spur.SshShell(hostname=srv_name(), useraname="root", password="3tango11")
#  result = shell.run([])
#  print result.output
activate_mst()

# All S/Ns of cabless connected to the HCA
#function serial_numbers_of_cables(){
#serial_numbers=$(sshpass -p 3tango ssh root@${srv} 'mlxcables' | awk '/'"Serial number"'/{print $4}')
#echo "S/N of cables connected to the HCA's ports:"
#echo "${serial_numbers}"
#}

#function device_name_of_active_port(){
#dev_name=$(sshpass -p 3tango ssh root@${srv} '/hpc/local/bin/lshca -s mst' | awk '/'"actv"'/ {print $28}')
#echo "${dev_name}"
#}

#function get_array_of_switch_ports(){
#arr="1/1"
#port=2
#while [ $port -ne 33 ]
#do
#arr+=( "1/${port}" )
#port=$[ $port + 1 ]
#done
#echo "${arr[*]}"
#}
#
#array_sw=("leaf-switch-62" "leaf-switch-64" "core-switch")
#
##check switch_list and get  port name
#function check_convergence(){
#for sn in $(serial_numbers_of_cables); do
#  for sw in ${array_sw[@]}; do
#    for p in $(get_array_of_switch_ports); do
#    cli=$(sshpass -p admin ssh admin@${sw} cli \"enable\" \"show interfaces ethernet ${p} transceiver\" | awk '/'"serial number"'/{print $4}')
#    if [ "${sn}" == "${cli}" ]; then
#      echo "Switch: [ ${sw} ]; Port: [ ${p} ]; S/N: [ ${sn} ]"
#    else
#      echo "not found" > /dev/null
#    fi
#    done
#  done
#done
#}

