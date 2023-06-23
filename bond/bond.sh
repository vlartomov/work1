#!/bin/bash

  echo "
DEVICE=bond0
NAME=bond0
TYPE=bond
BONDING_MASTER=yes
IPADDR=2.1.4.2
NETMASK=255.255.255.0
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
# mode is LACP
BONDING_OPTS=\"mode=802.3ad miimon=100 updelay=100 downdelay=100 xmit_hash_policy=layer3+4\"
  " > /etc/sysconfig/network-scripts/ifcfg-bond0

  echo "
DEVICE=enp2s0f0
TYPE=Ethernet
ONBOOT=yes
MASTER=bond0
SLAVE=yes
BOOTPROTO=none
  " > /etc/sysconfig/network-scripts/ifcfg-enp2s0f0

  echo "
DEVICE=enp2s0f1
TYPE=Ethernet
ONBOOT=yes
MASTER=bond0
SLAVE=yes
BOOTPROTO=none
  " > /etc/sysconfig/network-scripts/ifcfg-enp2s0f1

if [[ $HOSTNAME =~   sputnik1 ]] ; then
 sed -i 's/IPADDR=.*/IPADDR=2\.1\.4\.1/' /etc/sysconfig/network-scripts/ifcfg-bond0
elif [[ $HOSTNAME =~ sputnik2 ]] ; then
 sed -i 's/IPADDR=.*/IPADDR=2\.1\.4\.2/' /etc/sysconfig/network-scripts/ifcfg-bond0
elif [[ $HOSTNAME =~ sputnik3 ]] ; then
 sed -i 's/IPADDR=.*/IPADDR=2\.1\.4\.3/' /etc/sysconfig/network-scripts/ifcfg-bond0
elif [[ $HOSTNAME =~ sputnik4 ]] ; then
 sed -i 's/IPADDR=.*/IPADDR=2\.1\.4\.4/' /etc/sysconfig/network-scripts/ifcfg-bond0
fi

service network restart
service openibd restart

