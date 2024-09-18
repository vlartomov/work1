import requests
import json

def process_url(url, headers):
    response = requests.get(url, headers=headers)
    json_data = response.json()
    results = json_data.get('results', [])
    
    for device in results:
        device_role = device.get('device_role', {})
        role_name = device_role.get('name', '')
        
        if role_name in ["Server", "Ethernet Switch", "InfiniBand Switch"]:
            hostname = device.get('name', '')
            rack = device.get('rack', {}).get('name', '')
            print("Hostname: {}, Rack: {}".format(hostname, rack))
        else:
            print("Skipping device with role: {}".format(role_name))

headers = {
    'content-type': "application/json",
    'authorization': "Token a5d4c2a1dd356f03089667d11e4be43eaa95e99e",
    'cache-control': "no-cache",
    'postman-token': "070ad972-afce-1636-9f8d-e98a1c816ecb"
}

url1 = "http://swx-nbx/api/dcim/devices/?limit=900000000000"
url2 = "http://swx-nbx/api/dcim/devices/?limit=900000000000&offset=1000"

process_url(url1, headers)
process_url(url2, headers)


