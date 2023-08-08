#!/bin/python3
import sys
import requests
import json

api_url = r'http://swx-zabbix01/zabbix/api_jsonrpc.php'
head = {'Content-Type': 'application/json-rpc'}
get_version_data = {"jsonrpc":"2.0","method":"apiinfo.version", "params":{},"id":100}
cfg_file = r'./uniq_servers.xml'
with open(cfg_file, 'r')as f:
    xml_data = ''
    for line in f.readlines():
        xml_data += line

login_data={
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "username" : "Admin",
            "password" : "zabbix"
        },
        "id": 1
}
print("========================================")
resp = requests.post(url=api_url, headers=head, json=login_data)
print(resp.text)
print("========================================")

atuth_info = resp.json()["result"]

srv_data={
        "jsonrpc": "2.0",
        "method": "configuration.import",
        "params": {
            "format": "xml",
            "rules": {
                "hosts": {
                    "createMissing": True,
                    "updateExisting": False 
                },
                "templates": {
                    "createMissing": True,
                    "updateExisting": True
                },
                "items": {
                    "createMissing": True,
                    "updateExisting": True,
                    "deleteMissing": False 
                },
                "triggers": {
                    "createMissing": True,
                    "updateExisting": True,
                    "deleteMissing": False
                },
                "valueMaps": {
                    "createMissing": True,
                    "updateExisting": False
                }
            },
            "source": xml_data
        },
        "id": 1,
        "auth" : atuth_info
}

# actual data
resp = requests.post(url=api_url, headers=head, json=srv_data)
if int(resp.status_code / 10) != 20:
    print(f'Could not execute import of servers data:\n{resp.text}')
    sys.exit(1)
res_json = resp.json()
print(resp.text)

if str(res_json['result']).lower() != 'true':
    print(f'Import failed:\n{res_json}')

logout_data={
        "jsonrpc": "2.0",
        "method": "user.logout",
        "params": [],
        "id": 1,
        "auth" : atuth_info
}
print("========================================")
resp = requests.post(url=api_url, headers=head, json=logout_data)
print(resp.text)
print("========================================")
