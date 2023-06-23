#!/bin/bash


ACTION=$1
INTERFACE=$2
BOND_MEMBERS=""
ROCE_STATUS="unknown"
RC=0

trap "exit 1" TERM
export TOP_PID=$$

function check_prereq() {
  local util
  local util_list="cma_roce_tos mlnx_qos mlxconfig"
  local rc

  for util in ${util_list} ; do
    rc=$(which ${util} &> /dev/null; echo $?)
    if [ $rc -ne 0 ] ; then
      echo "Following prerequisite utility is missing: ${util}"
      exit 1
    fi
  done

  if [ $(whoami) != "root" ] ; then
    echo "Error: this script should be executed by root"
    exit 1
  fi
}

function usage() {
  echo
  echo "This script gets or sets HCA lossless RoCE "
  echo "based on this document https://community.mellanox.com/docs/DOC-2881"
  echo
  echo "Usage: ./hca_lossless_roce.sh <set|get> <interface>"
  echo " get -  show interface RoCE status"
  echo " set -  set interface RoCE to Lossless"
  echo " interface - "
  echo "        interface name"
  echo
  echo "Example: ./hca_lossless_roce.sh get p1p2"
  echo
}

function exec_cmd() {
  local cmd=$1
  local rc
  local result

  result=$(eval ${cmd} )
  rc="$?"

  if [ ${rc} -ne 0 ] ; then
    echo 1>&2
    echo "Error - following cmd failed:" 1>&2
    echo "${cmd}" 1>&2
    echo "Result:" 1>&2
    echo "${result}" 1>&2
    kill -s TERM $TOP_PID
  fi

  echo "${result}"
}

function set_bond_members_state() {
  local action=$1
  local int

  if [ "${BOND_MEMBERS}x" == "x" ] ; then
    return
  fi

  for int in ${BOND_MEMBERS} ; do
    echo "Setting ${int} interface \"${action}\""
    ip link set ${int} ${action}
  done
}

function get_lossless_status() {
  local expected_result
  local interface
  local interface_list
  local qos
  local result

  ROCE_STATUS="Lossless"

  if [ "${BOND_MEMBERS}x" == "x" ] ; then
    interface_list="${INTERFACE}"
  else
    interface_list="${BOND_MEMBERS}"
  fi

  for interface in ${interface_list} ; do
    echo "Getting configuration for ${interface}"

    qos=$(exec_cmd "mlnx_qos -i ${interface}")

    expected_result="dscp"
    result=$(echo "${qos}" | awk '/Priority trust state:/{print $NF}')
    if [ "${result}" == "${expected_result}" ] ; then
      echo "Priority trust state is cofigured to Lossless: ${result}"
    else
      echo "Priority trust state is NOT cofigured to Lossless: ${result}. Expected ${expected_result}"
      ROCE_STATUS="Lossy"
    fi

    expected_result="00010000"
    result=$(echo "${qos}" | awk --re-interval '/^[[:space:]]+enabled[[:space:]]+[0-9]/{$1=""; print}' | tr -d ' ')
    if [ "${result}" == "${expected_result}" ] ; then
      echo "PFC is cofigured to Lossless: ${result}"
    else
      echo "PFC is NOT cofigured to Lossless: ${result}. Expected ${expected_result}"
      ROCE_STATUS="Lossy"
    fi
    echo
  done

  expected_result="Global tclass=106"
  result=$(exec_cmd "cat /sys/class/infiniband/${MLNX_DEVICE}/tc/1/traffic_class")
  if [ "${result}" == "${expected_result}" ] ; then
    echo "Traffic Class is cofigured to Lossless: ${result}"
  else
    echo "Traffic Class is NOT cofigured to Lossless: \"${result}\". Expected ${expected_result}"
    ROCE_STATUS="Lossy"
  fi

  expected_result="106"
  result=$(exec_cmd " cma_roce_tos -d ${MLNX_DEVICE}")
  if [ "${result}" == "${expected_result}" ] ; then
    echo "RDMA-CM ToS is cofigured to Lossless: ${result}"
  else
    echo "RDMA-CM ToS is NOT cofigured to Lossless: ${result}. Expected ${expected_result}"
    ROCE_STATUS="Lossy"
  fi

  expected_result="1"
  result=$(exec_cmd "sysctl net.ipv4.tcp_ecn" | awk '{print $NF}')
  if [ "${result}" == "${expected_result}" ] ; then
    echo "TCP ECN is cofigured to Lossless: ${result}"
  else
    echo "TCP ECN is NOT cofigured to Lossless: ${result}. Expected ${expected_result}"
    ROCE_STATUS="Lossy"
  fi

  echo
  echo "${INTERFACE} RoCE status ===> ${ROCE_STATUS} <==="

  if [ "${ROCE_STATUS}" != "Lossless" ] ; then
    RC=1
  fi
}

function set_lossless_status() {
  local cmd
  local i
  local result
  local interface
  local interface_list

  echo "Setting interface ${INTERFACE} RoCE to Lossless"
  if [ "${BOND_MEMBERS}x" == "x" ] ; then
    interface_list="${INTERFACE}"
  else
    interface_list="${BOND_MEMBERS}"
  fi

  set_bond_members_state down
  for interface in ${interface_list} ; do

    int_cmd[0]="mlnx_qos -i ${interface} --pfc 0,0,0,1,0,0,0,0"
    int_cmd[1]="mlnx_qos -i ${interface} --trust dscp"

    for i in $(seq 0 $(( ${#int_cmd[@]} - 1 )) ) ; do
      echo "Running:  ${int_cmd[${i}]}"
      exec_cmd "${int_cmd[${i}]}" > /dev/null
    done
  done
  set_bond_members_state up

  cmd[0]="echo 106 > /sys/class/infiniband/${MLNX_DEVICE}/tc/1/traffic_class"
  cmd[1]="cma_roce_tos -d ${MLNX_DEVICE} -t 106"
  cmd[2]="sysctl -w net.ipv4.tcp_ecn=1"

  for i in $(seq 0 $(( ${#cmd[@]} - 1 )) ) ; do
    echo "Running:  ${cmd[${i}]}"
    exec_cmd "${cmd[${i}]}" > /dev/null
  done

  echo
  result=$(get_lossless_status ${INTERFACE})
  if [ $( echo "${result}" | grep ${INTERFACE} | grep -c "Lossless" ) -gt 0  ] ; then
    echo "Success: set interface ${INTERFACE} RoCE to Lossless"
  else
    echo "FAILED: could not set interface ${INTERFACE} RoCE to Lossless"
    echo
    echo "See current status below:"
    echo "${result}"
    exit 1
  fi
}

check_prereq

if [ "X${INTERFACE}" == "X" ] ; then
  echo "Error: missing INTERFACE parameter"
  usage
  exit 1
fi


rc=$(ifconfig ${INTERFACE} &> /dev/null ; echo $?)
if [ ${rc} -ne 0 ] ; then
  echo "Error: no such INTERFACE - ${INTERFACE} "
  exit 1
fi

if [ -f /proc/net/bonding/${INTERFACE} ] ; then
  echo -e "\n${INTERFACE} is a BOND device\n\n"
  result=$(cat /proc/net/bonding/${INTERFACE}  | awk '/Slave Interface:/{printf $NF" "}')
  if [ "${result}x" == "x" ] ; then
    echo "Error: failed to identify BOND members"
    exit 1
  else
    BOND_MEMBERS="${result}"
  fi
fi

if [ "${BOND_MEMBERS}x" == "x" ] ; then
  interface_string=${INTERFACE}
else
  interface_string="${INTERFACE}"'/slave_*'
fi

result=$(ls -1 /sys/class/net/${interface_string}/device/infiniband/ 2> /dev/null | wc -l)
if [ ${result} -eq 0 ] ; then
  echo "Error: interface ${INTERFACE} is probably not a mellanox device"
  exit 1
elif [ ${result} -gt 1 ] ; then
  echo "Error: Only CX4 and later devices supported"
  exit 1
else
  MLNX_DEVICE=$(ls -1 /sys/class/net/${interface_string}/device/infiniband/)
fi

result=$(cat /sys/class/net/${interface_string}/device/infiniband/${MLNX_DEVICE}/ports/1/link_layer 2> /dev/null)

if [ "${result}" != "Ethernet" ] ; then
  echo "Error: interface ${INTERFACE} is not Ethernet device"
  exit 1
fi


if [ "${ACTION}" == "get" ] ; then
  get_lossless_status
elif [ "${ACTION}" == "set" ] ; then
  set_lossless_status
fi

exit ${RC}
~
~
~

