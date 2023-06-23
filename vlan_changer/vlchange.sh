#!/bin/bash
#sshpass -p '3tango11' ssh labs@10.0.58.115 './script3.sh'

function cd_to_script(){
cd /home/labs/02ChangeVLANs/menu.py 
}
sshpass -p '3tango11' ssh labs@10.0.58.115 $(cd_to_script)
