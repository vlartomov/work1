#These steps describing the opportunity to get actual information from "NetBox" and import to "Zabbix"
1. To launch the comand "python postman_request.py > postman_data.txt" result in postman_data.txt
2. To launch the script "get_ip_addr.sh"
     you will get two files (unavailable_servers.txt and uniq_servers.txt)
    - unavailable_servers.txt - this file has list of all unpingble by mgmt port servers
    - uniq_servers.txt - servers which will be added to the zabbix.
3. To launch "zabbix-mass_stations_V2.sh" which convert "uniq_servers.txt" file to zabbix import file "uniq_servers.xml".


