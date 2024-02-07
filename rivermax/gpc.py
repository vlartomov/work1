#!/usr/local/bin/python3.7

import mysql.connector

# To call the script use "/usr/local/bin/python3.7 python_hosts_port_sql_source.py"

def read_serial_numbers_from_db():
    # Connect to the database
    mydb = mysql.connector.connect(
        host="localhost",
        user="root",
        password="3tango11",
        database="serial_numbers"
    )

    cursor = mydb.cursor()

    cursor.execute("SELECT hostname, serial_number FROM host_serial_numbers;")
    rows = cursor.fetchall()

    # Close the cursor and the connection
    cursor.close()
    mydb.close()

    data = {}
    for row in rows:
        hostname, serial_number = row
        if hostname.lower() not in data:
            data[hostname.lower()] = []
        data[hostname.lower()].append(serial_number)

    return data

def find_similar_serial_numbers(target_host, all_hosts):
    target_serial_numbers = set(all_hosts.get(target_host.lower(), []))
    similar_hosts = {}

    for host, serial_numbers in all_hosts.items():
        if host == target_host.lower():
            continue

        common_serial_numbers = target_serial_numbers.intersection(set(serial_numbers))

        if common_serial_numbers:
            similar_hosts[host] = common_serial_numbers

    return similar_hosts

def main():
    all_hosts = read_serial_numbers_from_db()
    target_host = input("Enter the hostname to check for similar serial numbers: ").lower()

    if target_host not in all_hosts:
        print(f"No data available for host {target_host}")
        return

    similar_hosts = find_similar_serial_numbers(target_host, all_hosts)

    if similar_hosts:
        for host, common_serial_numbers in similar_hosts.items():
            print(f"{host} has similar serial numbers: {', '.join(common_serial_numbers)}")
    else:
        print("No hosts with similar serial numbers found.")

if __name__ == "__main__":
    main()

