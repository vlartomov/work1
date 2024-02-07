#!/usr/local/bin/python3.7
import mysql.connector
import re

# Establish MySQL connection
mydb = mysql.connector.connect(
    host="localhost",
    user="root",
    password="3tango11",
    database="serial_numbers"
)

cursor = mydb.cursor()

# Read sn_data.txt file
with open("sn_data.txt", "r") as file:
    lines = file.readlines()

# Parse each line and insert into MySQL
for line in lines:
    line = line.strip()
    hostname, serial_numbers_str = re.match(r"(.+?): (.+)", line).groups()
    serial_numbers_list = eval(serial_numbers_str)  # Be careful with eval; make sure the input is trusted or sanitized

    for serial_number in serial_numbers_list:
        if serial_number:  # Check if serial_number is not empty
            cursor.execute("INSERT INTO host_serial_numbers (hostname, serial_number) VALUES (%s, %s)", (hostname, serial_number))
            mydb.commit()

# Close the connection
cursor.close()
mydb.close()
