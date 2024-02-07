#!/bin/bash

# Launch python postman_request.py
echo "Launching python postman_request.py..."
/bin/python3 /root/work1/zabbix_proj/postman_request.py > /root/work1/zabbix_proj/postman_data.txt

# Wait for the previous script to finish
echo "Waiting for python postman_request.py to finish..."
wait

# Launch get_ip_addr.sh
echo "Launching get_ip_addr.sh..."
/bin/bash /root/work1/zabbix_proj/get_ip_addr.sh

# Wait for the previous script to finish
echo "Waiting for get_ip_addr.sh to finish..."
wait

# Launch zabbix-mass_stations_V2.sh
echo "Launching zabbix-mass_stations_V2.sh..."
/bin/bash /root/work1/zabbix_proj/zabbix-mass_stations_V2.sh

# Wait for the previous script to finish
echo "Waiting for zabbix-mass_stations_V2.sh to finish..."
wait

# Launch zabbix_uploader.py
echo "Launching zabbix_uploader.py..."
/bin/python3 /root/work1/zabbix_proj/zabbix_uploader.py

# Wait for the previous script to finish
echo "Waiting for zabbix_uploader.py to finish..."
wait

echo "All scripts have finished executing."