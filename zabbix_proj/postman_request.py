import requests
import json

url = "http://swx-nbx/api/dcim/devices/?limit=100000"

headers = {
    'content-type': "application/json",
    'authorization': "Token a5d4c2a1dd356f03089667d11e4be43eaa95e99e",
    'cache-control': "no-cache",
    'postman-token': "070ad972-afce-1636-9f8d-e98a1c816ecb"
    }

response = requests.request("GET", url, headers=headers)
json_data = response.json()
results = json_data['results']

for device in results:
    server = device['device_role']['name']
    if server == "Server":
        hostname = device['name']
        rack = device['rack']['name']
        print(hostname + ' ' + rack)
#        OuttxtFile = open('listallfiles.txt', 'a')
#        OuttxtFile.write(hostname + ' ' + rack)
#        OuttxtFile.close() 
    else:
        continue
       
