"""
The script retrieves the server name from a Zabbix trigger,
uses Netbox's REST API for further processing,
and then sends an email notification to the server owner.
"""

import sys
import requests
import json
import subprocess

def send_email(email, server_name):
    message = f"""<p>The server <span style='color:red;'>{server_name}</span> is experiencing low storage space.<br>
The ' <span style='color:red;'>/</span> ' partition currently has less than 10 GB available.<br>
Please take the necessary actions to address this issue.</p>

<p>For additional information about the server please follow the links:</p>
<ul>
  <li><a href="http://swx-nbx/">http://swx-nbx/</a>     [readonly/readonly]</li>
  <li><a href="http://swx-zabbix01/zabbix/">http://swx-zabbix01/zabbix/</a>     [readonly/3tango11]</li>
</ul>"""

    subject = f"Urgent: Low Storage Space on the server {server_name}"
    command = f'echo "{message}" | mutt -e "set content_type=text/html" -s "{subject}" {email}'
    subprocess.run(command, shell=True)

def read_owner_list(url, headers):
    response = requests.request("GET", url, headers=headers)
    json_data = response.json()
    results = json_data['results']
    owner_dict = {}
    for device in results:
        contact_id = device['id']
        email = device['email']
        owner_dict[contact_id] = email
    return owner_

def process_url(url, headers, search_hostname, owner_list):
    response = requests.request("GET", url, headers=headers)
    json_data = response.json()
    results = json_data['results']
    for device in results:
        server = device['device_role']['name']
        if server == "Server":
            hostname = device['name']
            if hostname.lower() == search_hostname:
                contacts = device['custom_fields'].get('contacts')
                if contacts is not None:
                    owner_ids = contacts.get('ids', [])
                    if owner_ids:
                        owner_names = [owner_list[int(id)] for id in owner_ids if int(id) in owner_list]
                        print(hostname.lower(), owner_names)
                        for email in owner_names:
                            send_email(email, hostname.lower())  # Include the hostname as the server name
        else:
            continue

if len(sys.argv) < 2:
    print("Please provide the hostname as a command-line argument.")
    sys.exit(1)

search_hostname = sys.argv[1].lower()

headers = {
    'content-type': "application/json",
    'authorization': "Token a5d4c2a1dd356f03089667d11e4be43eaa95e99e",
    'cache-control': "no-cache",
    'postman-token': "070ad972-afce-1636-9f8d-e98a1c816ecb"
}

owner_list_url = "http://swx-nbx/api/tenancy/contacts/?limit=900"
owner_list = read_owner_list(owner_list_url, headers)

url1 = "http://swx-nbx/api/dcim/devices/?limit=900000000000"
url2 = "http://swx-nbx/api/dcim/devices/?limit=900000000000&offset=1000"

process_url(url1, headers, search_hostname, owner_list)
process_url(url2, headers, search_hostname, owner_list)


