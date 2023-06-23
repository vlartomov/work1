#!/usr/bin/python3

import subprocess
import sys
from pprint import pprint
from datetime import datetime
import requests
import time

EMAIL = ['vladimirar@nvidia.com']
#EMAIL_CC = ['miked@mellanox.com', 'yuriis@mellanox.com', 'lennyb@nvidia.com', 'lennyb@mellanox.com']
#EMAIL_CC = ['lennyb@nvidia.com']
DOMAIN = 'mellanox.com'

ILO_USER = 'root'
ILO_PSW = '3tango11'
DO_NOT_REBOOT = ['jazz06']

REBOOT = False
DEBUG = False

def extract_nodes(nodes):
    nodes_list = []
    for node in nodes:
        node_name = node.split('[')[0]
        nodes_range = []
        try:
            # Check if there is a node[] range
            nodes_range = node.split('[')[1].rstrip(']')
        except:
            # return node itself
            nodes_list.append(node_name)
            continue
        for node in nodes_range.split(','):
            node_range = node.split('-')
            try:
                for n in list(range(int(node_range[0]),int(node_range[1])+1)):
                    nodes_list.append("%s%s" % (node_name, str(n).zfill(2)))
            except Exception as e:
               nodes_list.append("%s%s" % (node_name, node_range[0]))
    nodes_list.sort()
    return nodes_list


def get_drained_nodes():
    sinfo_cmd = '/usr/bin/sinfo -o "%40N %.3D %9P %11T %.4c %.8z %.6m %.8d %.6w %32f %40E"|grep drain|sort|awk \'{print $1}\''
    process = subprocess.run(sinfo_cmd, shell=True, check=True, stdout=subprocess.PIPE).stdout.decode('ascii').replace('\n',' ').split()
    print(process)
    return process


def get_reserved_nodes():
    cmd = "scontrol show res|grep Nodes|awk '{print $1}'| cut -d'=' -f2|sort|sed 's/,/ /g'"
    process = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.replace(' ','\n').split()
    print(process)
    return process


def drained_and_reserved(all_drained_nodes):
    reserved_info = {}
    cmd = "scontrol show res"
    process = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, universal_newlines=True)
    for reservation in process.stdout.rstrip('\n').replace('   ','',).split("\n\n"):
        info = reservation.split('\n')
        for node in info[1].split()[0].split('=')[1].split(','):
            for n in extract_nodes([node]):
                if n in all_drained_nodes:
                    print("***********************")
                    pprint(info)
                    user = info[-1].split()[0].split('=')[1].split(',')[-1]
                    if not user in reserved_info.keys():
                        reserved_info [user] = []
                    reserved_info[user].append(n)
    pprint(reserved_info)
    return reserved_info


def list_diff(list1, list2):
    c = list(set(list1) - set(list2))
    c.sort()
    return c


def get_drain_info(node):
    sinfo_cmd = '/usr/bin/sinfo -N -n ' + node + ' -o "%E" |tail -n1'
    return subprocess.run(sinfo_cmd, shell=True, check=True, stdout=subprocess.PIPE).stdout.decode('ascii').replace('\n','')


def get_drain_info_nodes(nodes):
    s = ""
    for node in nodes:
        s = s + "%s %s" % (node.ljust(40), get_drain_info(node)) + "\n"
    return s

def prepare_email(all_drained_nodes, reserved_nodes, real_drained_nodes, drained_and_reserved_nodes):
    html_body = '/auto/UFM/CI_LOGS/tmp/drained_nodes.html'
    html = """
    <html><body>
    <br/>Dear <a href="mailto:%s@%s">%s,</a><br/>
    Going through our lab servers on %s I've noticed that some of the nodes are drained[1] and they are not reserved[2].<br>
    Please take a cup of coffee and check the nodes from the list below:<br><br>%s<br><br>
    """ % (EMAIL, DOMAIN, EMAIL[0].split('@')[0].capitalize(), datetime.now().strftime("%d/%m/%Y at %H:%M"), get_drain_info_nodes(real_drained_nodes).replace('\n','<br>'))
    fp = open(html_body,"w")
    fp.write(html)

    for user, nodes in drained_and_reserved_nodes.items():
        fp.write("Dear <a href=\"mailto:%s@%s\">%s,</a><br>We can't fix following drained nodes, since they reserved for you.<br>%s<br><br>" % (user.capitalize(), DOMAIN, user.capitalize(), nodes))

    fp.write("[1] All drained Nodes<br>%s<br>%s<br><br>" % (
                                                       '#/usr/bin/sinfo -o "%40N %.3D %9P %11T %.4c %.8z %.6m %.8d %.6w %32f %40E"', all_drained_nodes))
    fp.write("[2] All reserved Nodes<br>%s<br>%s<br><br>" % ('#scontrol show res', reserved_nodes))
    fp.write("Jenkins<br>Staff Engineer, DevOps, hpc-master<br>13 Zarchin St., Bldg B, Raanana 43362, Israel<br>NVIDIA<br><br>")
    fp.write("BTW, Did you know that %s?<br><br>" % requests.get('https://api.chucknorris.io/jokes/random').json()['value'])

    fp.close()
    email_cc = EMAIL_CC
    for user in drained_and_reserved_nodes.keys():
        email_cc.append("%s@%s" % (user, DOMAIN))

    cmd = "mutt -e 'set content_type=text/html' %s -c %s -s 'Jenkins Report: Drained Nodes' < %s" % ( ','.join(EMAIL), ','.join(email_cc), html_body)
    rc  = 0
    if not DEBUG:
        rc, o = subprocess.getstatusoutput(cmd)
        print("%s\n%s" % (cmd, o))
    else:
        print(cmd)
    return rc

def reboot_node(node):
    if node in DO_NOT_REBOOT:
        print("%s is in ignore list or REBOOT == False\n" % node)
        return 0
    cmd = 'ipmitool -I lanplus -H %s-ilo -U %s -P %s power cycle' % (node, ILO_USER, ILO_PSW)
    rc, o = subprocess.getstatusoutput(cmd)
    print("%s\n%s\nreturn value=%s" % (cmd, o, rc))
    return rc

def reboot_real_drained_nodes():
    reserved_nodes = extract_nodes(get_reserved_nodes())
    all_drained_nodes = extract_nodes(get_drained_nodes())
    real_drained_nodes = list_diff(all_drained_nodes, reserved_nodes)
    
    for node in real_drained_nodes:
        print("Rebooting drained %s" % node)
        reboot_node(node)
    print("Sleeping after reboot")
    time.sleep(1200)
    return 0


def main():

    if REBOOT == True:
        reboot_real_drained_nodes()
    reserved_nodes = extract_nodes(get_reserved_nodes())
    all_drained_nodes = extract_nodes(get_drained_nodes())
    real_drained_nodes = list_diff(all_drained_nodes, reserved_nodes) 
    drained_and_reserved_nodes = drained_and_reserved(all_drained_nodes)

    print("All drained nodes: %s" % (all_drained_nodes))
    print("ell reserved nodes: %s" % (reserved_nodes))
    print("Real drained nodes %s" % (real_drained_nodes))
    pprint(drained_and_reserved_nodes)

    return prepare_email(all_drained_nodes, reserved_nodes, real_drained_nodes, drained_and_reserved_nodes)
    

if __name__ == "__main__":
    sys.exit(main())
