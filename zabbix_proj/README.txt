
## Automation steps of collecting the information from "NetBox" and import to "Zabbix"

1. The file "/opt/inventory-automation/uniq_servers.txt" is copied from the server swx-nbx, each morning. (crontab)
2. The script "zabbix-mass_stations_V2.sh" converts "uniq_servers.txt" to zabbix import file "uniq_servers.xml". (crontab)
3. The script "zabbix_uploader.py" exports "uniq_servers.xml" to zabbix. (crontab)

