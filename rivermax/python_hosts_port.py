import ast

def read_serial_numbers(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        
    data = {}
    for line in lines:
        hostname, serial_numbers_str = line.strip().split(": ")
        serial_numbers_list = ast.literal_eval(serial_numbers_str)  # Convert string to list
        data[hostname.lower()] = serial_numbers_list  # Convert to lowercase for case-insensitive comparison

    return data

def find_similar_serial_numbers(target_host, all_hosts):
    target_serial_numbers = set(all_hosts.get(target_host.lower(), []))  # Convert to lowercase for case-insensitive comparison
    similar_hosts = {}

    for host, serial_numbers in all_hosts.items():
        if host == target_host.lower():  # Convert to lowercase for case-insensitive comparison
            continue
        
        common_serial_numbers = target_serial_numbers.intersection(set(serial_numbers))
        
        if common_serial_numbers:
            similar_hosts[host] = common_serial_numbers
            
    return similar_hosts

def main():
    all_hosts = read_serial_numbers("sn_data.txt")
    target_host = input("Enter the hostname to check for similar serial numbers: ").lower()  # Convert to lowercase for case-insensitive comparison

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
