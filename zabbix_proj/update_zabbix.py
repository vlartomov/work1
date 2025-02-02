#!/usr/bin/env python3

import yaml
import shutil

ZABBIX_FILE = "zbx_export_hosts.yaml"
IPMI_LIST_FILE = "ipmi_list_v2.txt"
BACKUP_FILE = f"{ZABBIX_FILE}.bak"

# IPMI credentials
IPMI_USERNAME = "root"
IPMI_PASSWORD = "3tango11"

# Backup original file before modification
shutil.copy(ZABBIX_FILE, BACKUP_FILE)

# Read IPMI mappings
ipmi_map = {}
with open(IPMI_LIST_FILE, "r") as f:
    for line in f:
        ilo_host, ilo_ip = line.strip().split()
        base_host = ilo_host.replace("-ilo", "")
        ipmi_map[base_host] = {"ilo_host": ilo_host, "ilo_ip": ilo_ip}

# Load YAML file
with open(ZABBIX_FILE, "r") as f:
    try:
        zbx_data = yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        print(f"ERROR: YAML parsing failed: {e}")
        exit(1)

# Ensure expected structure
if "zabbix_export" not in zbx_data or "hosts" not in zbx_data["zabbix_export"]:
    print("ERROR: YAML structure is incorrect. Expected 'zabbix_export' with 'hosts'.")
    exit(1)

# Process hosts
for host in zbx_data["zabbix_export"]["hosts"]:
    host_name = host.get("host")
    if host_name in ipmi_map:
        print(f"DEBUG: Processing {host_name}")

        # Ensure "interfaces" exists
        if "interfaces" not in host:
            host["interfaces"] = []

        # Check if IPMI interface is missing
        has_ipmi = any(iface.get("type") == "IPMI" for iface in host["interfaces"])

        if not has_ipmi:
            print(f"DEBUG: Adding IPMI interface for {host_name}")
            ipmi_details = ipmi_map[host_name]
            host["interfaces"].append({
                "type": "IPMI",
                "ip": ipmi_details["ilo_ip"],
                "dns": ipmi_details["ilo_host"],
                "port": "623",
                "interface_ref": "if2"
            })

        # Add IPMI credentials if not present
        if "ipmi_username" not in host:
            host["ipmi_username"] = IPMI_USERNAME
        if "ipmi_password" not in host:
            host["ipmi_password"] = IPMI_PASSWORD

        # Ensure "templates" exists
        if "templates" not in host:
            host["templates"] = []

        # Check if "IPMI Interface Status" template is missing
        has_ipmi_template = any(tpl.get("name") == "IPMI Interface Status" for tpl in host["templates"])

        if not has_ipmi_template:
            print(f"DEBUG: Adding IPMI Interface Status template for {host_name}")
            host["templates"].append({"name": "IPMI Interface Status"})

# Write updated YAML back to file
with open(ZABBIX_FILE, "w") as f:
    yaml.dump(zbx_data, f, default_flow_style=False)

print("Zabbix YAML file has been updated successfully.")
