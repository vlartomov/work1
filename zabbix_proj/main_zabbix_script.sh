#!/bin/bash

# Launch python postman_request.py
echo "Launching python postman_request.py..."
python postman_request.py > postman_data.txt

# Wait for the previous script to finish
echo "Waiting for python postman_request.py to finish..."
wait

# Launch get_ip_addr.sh
echo "Launching get_ip_addr.sh..."
bash get_ip_addr.sh

# Wait for the previous script to finish
echo "Waiting for get_ip_addr.sh to finish..."
wait

# Launch zabbix-mass_stations_V2.sh
echo "Launching zabbix-mass_stations_V2.sh..."
bash zabbix-mass_stations_V2.sh

# Wait for the previous script to finish
echo "Waiting for zabbix-mass_stations_V2.sh to finish..."
wait

echo "All scripts have finished executing."

