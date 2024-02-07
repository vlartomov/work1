#!/bin/bash
srv=${1}
echo "email notification from swx-zabbix01 the  service on server [${srv}] lost nfs dir /labhome/swx-azure-svc!!!" | mutt -s "NFS availability on server ${srv} is dead" -- vladimirar@nvidia.com

