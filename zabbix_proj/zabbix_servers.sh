#!/bin/bash

#***********************************************************************
#Начало пользовательских переменных
#Установите для них соответствующие значения перед выполнением сценария...
zabbixServer='swx-zbx'
zabbixUsername='Admin'
zabbixPassword='zabbix'
#Конец пользовательских переменных
#***********************************************************************

header='Content-Type:application/json-rpc'
zabbixApiUrl="http://$zabbixServer/api_jsonrpc.php"

function exit_with_error() {
  echo '********************************'
  echo "$errorMessage"
  echo '--------------------------------'
  echo 'Входные данные'
  echo '--------------------------------'
  echo "$json" $zabbixApiUrl
  echo '--------------------------------'
  echo 'Выходные данные'
  echo '--------------------------------'
  echo "$result"
  echo '********************************'
  exit 1
}

#------------------------------------------------------
# Аутентификация пользователя. https://www.zabbix.com/documentation/current/ru/manual/api/reference/user/login
#------------------------------------------------------
errorMessage='*ERROR* - Не удается получить токен авторизации Zabbix'
json=`echo {\"jsonrpc\": \"2.0\",\"method\":\"user.login\",\"params\":{\"user\": \"$zabbixUsername\",\"password\": \"$zabbixPassword\"},\"id\": 1 }`
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
auth=$(echo "${result}" |sed -e 's|.*result":"||' -e 's/","id.*//g')
check=$(echo "${auth}"|tr -d '\r\n'| sed -n 's/error.*/ERROR/Ip')
if [[ ${check} == *ERROR* ]]; then exit_with_error; fi
echo "Вход в систему выполнен успешно - Идентификатор авторизации: $auth"

# Запрос информации об авторизовавшемся пользователе
usinfo=`echo {\"jsonrpc\": \"2.0\",\"method\":\"user.login\",\"params\":{\"user\": \"$zabbixUsername\",\"password\": \"$zabbixPassword\", \"userData\": true},\"id\": 1 }`
infouser=`curl --silent --show-error --insecure --header $header --data "$usinfo" $zabbixApiUrl`
echo "${infouser}"

#------------------------------------------------------
# Выход из zabbix https://www.zabbix.com/documentation/current/ru/manual/api/reference/user/logout
#------------------------------------------------------
# Выполнение выхода из API.
errorMessage='*ERROR* - Не удалось выйти из системы'
usexit=`echo {\"jsonrpc\": \"2.0\",\"method\":\"user.logout\",\"params\": [],\"id\": 1, \"auth\": \"$auth\"}`
logout=`curl --silent --show-error --insecure --header $header --data "$usexit" $zabbixApiUrl`
check=$(echo "${logout}"|tr -d '\r\n'| sed -n 's/error.*/ERROR/Ip')
if [[ ${check} == *ERROR* ]]; then exit_with_error; fi
echo 'Успешно вышел из Zabbix' "${logout}"
