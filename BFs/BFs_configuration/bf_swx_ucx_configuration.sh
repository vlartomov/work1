#!/bin/bash

set -xvEe -o pipefail

HNAME=$1

# Script of root user configurations
./root_user_and_passwd_change.sh "$HNAME"
if [ $? -eq 0 ]; then
  echo -e "\n##  the root user and root_password updated successfully  ##"
  echo "============================================================"
else
  echo "finished with error"
  echo "============================================================"
fi

# Set automounts and necessary services
function set_automounts(){
  oob_net0_interf=$(sshpass -p '3tango' ssh -t root@$HNAME 'ip addr show oob_net0 | awk "/inet / {print \$2}" | cut -d "/" -f 1')
  IP_addr=$(echo "$oob_net0_interf" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
  /auto/GLIT/lab-support/scripts/mount_script/mount.sh -r "$IP_addr" -u root -p 3tango
}

function modify_system_configurations() {
  # Uncomment the specified line in /etc/gai.conf
  sshpass -p '3tango' ssh root@$HNAME 'sudo sed -i '\''s/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/'\'' /etc/gai.conf'

  # Create the directory /etc/systemd/system/autofs.service.d/
  sshpass -p '3tango' ssh root@$HNAME 'sudo mkdir -p /etc/systemd/system/autofs.service.d/'

  # Create the file /etc/systemd/system/autofs.service.d/override.conf with the specified content
  sshpass -p '3tango' ssh -t root@$HNAME << EOF
  echo -e "[Unit]\nAfter=ypbind.service\nRequires=ypbind.service" | sudo tee /etc/systemd/system/autofs.service.d/override.conf >/dev/null
EOF
}

function modify_netplan_50() {
  # Rename the file /etc/netplan/50-cloud-init.yaml to /etc/netplan/50-cloud-init.yaml_old
  sshpass -p '3tango' ssh root@$HNAME 'sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml_old'

  # Add the specified content to a new file /etc/netplan/50-cloud-init.yaml
  sshpass -p '3tango' ssh -t root@$HNAME << EOF
    cat << EOT | sudo tee /etc/netplan/50-cloud-init.yaml >/dev/null
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        oob_net0:
            dhcp4: true
        tmfifo_net0:
            addresses:
            - 192.168.100.2/30
            dhcp4: false
#            nameservers:
#                addresses:
#                - 192.168.100.1
#            routes:
#            -   metric: 1025
#                to: 0.0.0.0/0
#                via: 192.168.100.1
#    renderer: NetworkManager
    renderer: networkd
    version: 2
EOT
EOF
}

# Replace sudors root access to BFB
function root_access_and_sudoers(){
  sshpass -p 3tango ssh root@$HNAME 'sudo sed -i '\''s/#PermitRootLogin prohibit-password/PermitRootLogin yes/'\'' /etc/ssh/sshd_config'
  sshpass -p 3tango ssh root@$HNAME 'sudo systemctl restart ssh'
  sshpass -p 3tango ssh root@$HNAME 'cp /.autodirect/mtrswgwork/rshaligin/NVME_setup/offload/RnD/rnd2/sudoers	/etc/'
}

function modules_for_hpc(){
  sshpass -p 3tango ssh root@$HNAME 'sudo apt install -y environment-modules'
  new_row="/hpc/local/etc/modulefiles                              # hpcx modules "
  sshpass -p '3tango' ssh -t root@$HNAME << EOF
      echo "$new_row" | sudo tee -a /etc/environment-modules/modulespath >/dev/null
EOF
}

set_automounts
sleep 30
modify_system_configurations
modify_netplan_50
sshpass -p "3tango" ssh root@$HNAME 'bash -s' < slurm_inst.sh
root_access_and_sudoers
modules_for_hpc
nohup sshpass -p 3tango ssh root@bf-dpu-ucx08 'reboot' > /dev/null 2>&1 &

echo "Waiting for server to reboot..."
sleep 300

until sshpass -p 3tango ssh -o ConnectTimeout=10 -o ConnectionAttempts=1 root@bf-dpu-ucx08 true; do
    echo "Waiting for SSH service to come back online..."
    sleep 10
done

echo "SSH service is available."

sshpass -p 3tango ssh root@bf-dpu-ucx08 'env node=compute site=MTR sync_slurm=yes sync_nhc=yes restart_slurm=yes \
    /hpc/noarch/git_projects/swx_infrastructure/slurm/update_tools/update_node_self.sh'



