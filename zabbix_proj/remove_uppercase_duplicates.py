import xml.etree.ElementTree as ET

# Parse the XML file
tree = ET.parse('zbx_export_hosts.xml')
root = tree.getroot()

# Find the <hosts> element
hosts_element = root.find('hosts')

# Dictionary to group hosts by lowercase host name
hosts_dict = {}

# Iterate over each <host> element
for host in hosts_element.findall('host'):
    host_name = host.find('host').text
    host_name_lower = host_name.lower()
    
    if host_name_lower in hosts_dict:
        hosts_dict[host_name_lower].append(host)
    else:
        hosts_dict[host_name_lower] = [host]

# List to keep track of hosts to remove
hosts_to_remove = []

# For each group of hosts with the same lowercase name
for host_list in hosts_dict.values():
    if len(host_list) > 1:
        # Remove uppercase hosts among duplicates
        for host in host_list:
            host_name = host.find('host').text
            if host_name.isupper():
                hosts_to_remove.append(host)

# Remove the marked hosts
for host in hosts_to_remove:
    hosts_element.remove(host)

# Write the updated XML to a new file
tree.write('zbx_export_hosts_modified.xml', encoding='UTF-8', xml_declaration=True)
