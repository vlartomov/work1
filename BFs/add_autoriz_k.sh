#!/bin/bash
srv_list=$(awk '{print $1}' hail.txt)

#loop test using functions
for srv in ${srv_list}; do
  auto_k=$(sshpass -p 3tango ssh root@swx-snap1 'cat /root/.ssh/id_rsa.pub')
  cli=$(sshpass -p 3tango ssh root@${srv} 'echo "${auto_k}" >> /root/.ssh/authorized_keys')
  echo "${cli}"
done
