#These steps describing the opportunity to get actual information from "NetBox" and import to "Zabbix"
1. Launch the script "main_zabbix_script.sh" which will call all other discribed bellow.
  a. "python postman_request.py > postman_data.txt" result in postman_data.txt
  b. "get_ip_addr.sh" - you will get two files (unavailable_servers.txt and uniq_servers.txt)
    	- unavailable_servers.txt - this file has list of all unpingble by mgmt port servers
    	- uniq_servers.txt - servers which will be added to the zabbix.
  c. "zabbix-mass_stations_V2.sh" which convert "uniq_servers.txt" file to zabbix import file "uniq_servers.xml".


