#!/bin/bash
srv=${1}
echo "email notification from swx-zabbix01 the nv_peer_mem service on server [${srv}] is inactive!!!" | mutt -s "nv_peer_mem on server ${srv} is dead" -- arivkin@nvidia.com

