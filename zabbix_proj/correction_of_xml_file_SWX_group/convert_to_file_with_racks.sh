#!/bin/bash
#awk 'NR==FNR{a[$1]=$2; next} $2 in a{print $0, a[$2]}' postman_data.txt uniq_servers.txt > result.txt

awk 'NR==FNR{if (NF == 2) a[$1]=$2; next} $2 in a{print $0, a[$2]}' postman_data.txt uniq_servers.txt > result.txt

