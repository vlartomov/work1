# WHAT DOES IT !?
# This is Zabbix_Mass_Stations automation to insert bulky information to Zabbix Server .
# It's really useful when the user wants to add lots of information such as stasions in one action, not one by one (it's really horrible one by one !)
export TERM=xterm
clear

rm -f "/root/work1/zabbix_proj/uniq_servers.xml"

f_input="/root/work1/zabbix_proj/uniq_servers.txt"

f_output="/root/work1/zabbix_proj/uniq_servers.xml"

f_group="SWX"

#'File Output:' ;

printf "<?xml version='1.0' encoding='UTF-8'?> \n" >> $f_output;
printf "<zabbix_export> \n" >> $f_output;
printf "\t<version>5.2</version> \n" >> $f_output;
printf "\t<date>"`date +"%Y-%m-%dT%TZ"`"</date> \n" >> $f_output;
printf "\t<groups> \n" >> $f_output;
printf "\t\t<group> \n" >> $f_output;
printf "\t\t\t<name>"$f_group"</name> \n" >> $f_output;
printf "\t\t</group> \n" >> $f_output;
printf "\t</groups> \n" >> $f_output;
printf "\t<hosts> \n" >> $f_output;

awk  -v Template="Template Module ICMP Ping" -v Group="${f_group%%*( )}" 'BEGIN {FS = " "} {IP=$1; hostname=$2}
        {printf "<host>\n";
         printf "\t<host>"hostname"</host>\n";
         printf "\t<name>"hostname"</name>\n";
		 printf "\t<templates>\n";
         printf "\t<template>\n";
         printf "\t<name>"Template"</name>\n";
         printf "\t</template>\n";
         printf "\t</templates>\n";
         printf "\t<groups>\n";
         printf "\t<group>\n";
         printf "\t<name>"Group"</name>\n";
         printf "\t</group>\n";
         printf "\t</groups>\n";
         printf "\t<interfaces>\n";
         printf "\t<interface>\n";
         printf "\t<ip>"IP"</ip>";
         printf "\t<interface_ref>if1</interface_ref>\n";
         printf "\t</interface>\n";
         printf "\t</interfaces>\n";
         printf "\t<inventory_mode>DISABLED</inventory_mode>\n";
         printf "</host>\n";    }' $f_input >>$f_output

printf "\n \t</hosts> \n" >> $f_output;
printf "</zabbix_export>  \n" >> $f_output;



