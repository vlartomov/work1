#!/bin/bash

curl -i -k -X POST -H 'Content-Type: application/json-rpc' -d '
{
    "jsonrpc": "2.0",
    "method": "host.get",
    "params": {
        "output": ["hostid","name"],
        "filter": {"host":""}
    },
    "auth": "XXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "id": 0
} ' http://swx-zbx/api_jsonrpc.php
