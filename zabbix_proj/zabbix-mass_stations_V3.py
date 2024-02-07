import xml.etree.ElementTree as ET
import datetime
import xml.dom.minidom as minidom


f_input = "/root/work1/zabbix_proj/uniq_servers.txt"
f_output = "/root/work1/zabbix_proj/uniq_servers.xml"
f_group = "SWX"
template = "Template Module ICMP Ping"

# Create root element
root = ET.Element("zabbix_export")

# Add version and date elements
version = ET.SubElement(root, "version")
version.text = "6.0"

date = ET.SubElement(root, "date")
date.text = datetime.datetime.utcnow().strftime("%Y-%m-%dT%TZ")

# Add groups element
groups = ET.SubElement(root, "groups")
group = ET.SubElement(groups, "group")
group_name = ET.SubElement(group, "name")
group_name.text = f_group

# Add hosts element
hosts = ET.SubElement(root, "hosts")

# Read input file and generate host elements
with open(f_input, "r") as input_file:
    for line in input_file:
        ip, hostname, additional_group = line.strip().split()

        host = ET.SubElement(hosts, "host")

        host_name = ET.SubElement(host, "host")
        host_name.text = hostname

        name = ET.SubElement(host, "name")
        name.text = hostname

        templates = ET.SubElement(host, "templates")
        template_element = ET.SubElement(templates, "template")
        template_name = ET.SubElement(template_element, "name")
        template_name.text = template

        host_groups = ET.SubElement(host, "groups")
        group_element1 = ET.SubElement(host_groups, "group")
        group_name1 = ET.SubElement(group_element1, "name")
        group_name1.text = f_group

        group_element2 = ET.SubElement(host_groups, "group")
        group_name2 = ET.SubElement(group_element2, "name")
        group_name2.text = additional_group

        interfaces = ET.SubElement(host, "interfaces")
        interface = ET.SubElement(interfaces, "interface")
        ip_element = ET.SubElement(interface, "ip")
        ip_element.text = ip

        interface_ref = ET.SubElement(interface, "interface_ref")
        interface_ref.text = "if1"

        inventory_mode = ET.SubElement(host, "inventory_mode")
        inventory_mode.text = "DISABLED"

# Generate XML file
tree = ET.ElementTree(root)
output = minidom.parseString(ET.tostring(root)).toprettyxml(indent="\t")

with open(f_output, "w") as output_file:
    output_file.write(output)

