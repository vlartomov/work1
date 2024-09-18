import requests
import json

def process_url(url, headers, server_list):
    response = requests.request("GET", url, headers=headers)
    json_data = response.json()
    results = json_data['results']

    for device in results:
        server = device['device_role']['name']
        hostname = device['name'].lower()

        if server in ["Server", "Ethernet Switch", "InfiniBand Switch"] and hostname in server_list:
            # Default owner_name if none is found
            owner_name = "No Owner"

            # Check for contacts in custom_fields
            if device.get('custom_fields') and 'contacts' in device['custom_fields']:
                owner_info = device['custom_fields']['contacts']
                if owner_info:
                    owners = owner_info.get('display', [])
                    owner_name = owners[0].split('->')[0].strip() if owners else "No Owner"

            print("{} {}".format(hostname.lower(), owner_name))

def load_server_list(filename):
    with open(filename, 'r') as file:
        return [line.strip() for line in file]

headers = {
    'content-type': "application/json",
    'authorization': "Token a5d4c2a1dd356f03089667d11e4be43eaa95e99e",
    'cache-control': "no-cache",
}

server_list = [s.lower() for s in load_server_list("list.txt")]

url1 = "http://swx-nbx/api/dcim/devices/?limit=900000000000"
url2 = "http://swx-nbx/api/dcim/devices/?limit=900000000000&offset=1000"

process_url(url1, headers, server_list)
process_url(url2, headers, server_list)
