#!/usr/src/Python-3.7.7/python
import subprocess
import os
import sys

hostname = (sys.argv[1])
if hostname = False:
  print('please enter hostname: ')
#s4itivaem hostname
#hostname = raw_input('Enter hostname: ')
ssh = subprocess.Popen(["ssh", "-i .ssh/id_rsa", hostname],
                        stdin =subprocess.PIPE,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True,
                        bufsize=0)
 
# Send ssh commands to stdin
ssh.stdin.write("uname -a\n")
ssh.stdin.write("uptime\n")
ssh.stdin.write("/hpc/local/bin/lshca")
ssh.stdin.close()

# Fetch output
for line in ssh.stdout:
    print(line.strip())
