import yaml

# Specify the path to your YAML file
yaml_file_path = 'zbx_export_hosts.yaml'

# Read the YAML file
with open(yaml_file_path, 'r') as file:
    yaml_content = file.read()

# Parse the YAML content
data = yaml.safe_load(yaml_content)

# Extract hostnames
hostnames = [host['host'] for host in data['zabbix_export']['hosts']]

# Print the hostnames
for hostname in hostnames:
    print(hostname)

