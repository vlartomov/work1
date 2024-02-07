import requests
import json

def process_url(url, headers):
    response = requests.request("GET", url, headers=headers)
    json_data = response.json()
    results = json_data['results']

    for device in results:
        contact_id = device['id']
        email = device['email']
        print(f'{contact_id} {email}')


headers = {
    'content-type': "application/json",
    'authorization': "Token a5d4c2a1dd356f03089667d11e4be43eaa95e99e",
    'cache-control': "no-cache",
    'postman-token': "070ad972-afce-1636-9f8d-e98a1c816ecb"
    }

url1 = "http://swx-nbx/api/tenancy/contacts/?limit=900"

process_url(url1, headers)

