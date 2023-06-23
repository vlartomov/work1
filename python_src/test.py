#!/usr/src/Python-3.7.7/python
import os
import paramiko
import subprocess
import sys
from pprint import pprint
from datetime import datetime
import requests
import time

ILO_USER = 'root'
ILO_PSW = '3tango11'
node = str(raw_input("Enter hostname: ")) 

#s4itivaem hostname
def srv_name():
  print('=====================')
  print(node)
  print('=====================')
  stream = os.popen('cat /etc/*release')
  output = stream.read()
  print(output.strip())
srv_name()

process = subprocess.Popen(['ping', '-c 4', node], 
                           stdout=subprocess.PIPE,
                           universal_newlines=True)

while True:
    output = process.stdout.readline()
    print(output.strip())
    # Do something else
    return_code = process.poll()
    if return_code is not None:
        print('RETURN CODE', return_code)
        # Process has finished, read rest of the output 
        for output in process.stdout.readlines():
            print(output.strip())
        break

process2 = subprocess.Popen(['ipmitool', '-I', 'lanplus', '-U', 'root', '-P', '3tango11', '-H', node, '-ilo', 'lan', 'print'],
                           stdout=subprocess.PIPE,
                           universal_newlines=True)

while True:
    output = process2.stdout.readline()
    print(output.strip())
    # Do something else
    return_code = process2.poll()
    if return_code is not None:
        print('RETURN CODE', return_code)
        # Process has finished, read rest of the output
        for output in process2.stdout.readlines():
            print(output.strip())
        break



#ipmitool -I lanplus -U root -P 3tango11 -H rapid01-ilo lan print
