#!/bin/bash
echo "email notification from swx-snap1" | mutt -a "/root/work1/zabbix_proj/unavailable_servers.txt" -s "unavailable list of servers" -- vladimirar@nvidia.com
#,ikostrov@nvidia.com
