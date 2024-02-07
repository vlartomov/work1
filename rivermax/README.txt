The script "create_sn_data_file.sh" added to the crontab and every morning creats
     the file "sn_data.txt" based on the list of servers "list1.txt".
The cript "build_sql_table.py" fills in the database "serial_numbers" using the file "sn_data.txt".
The main script "python_hosts_port_sql_source.py" using the mysql database "serial_numbers"
     asks to enter the hostname and then compares the entered hostname with existed database.

JFY: 
To call the script use "python_hosts_port_sql_source.py"
  or "./gpc.py"
The script "python_hosts_port.py" is the old version which uses the "sn_data.txt". (not mysql database!!!)
