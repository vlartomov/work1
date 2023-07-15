#!/bin/bash

set -xvEe -o pipefail

cat <<EOF > /etc/apt/sources.list.d/slurm.list
deb http://swx-repos.mtr.labs.mlnx/repository/swx-infra-ub2204/ jammy main
EOF

apt-key adv --recv-key --keyserver keyserver.ubuntu.com 50900053894A4767

cat <<EOF > /etc/apt/preferences.d/50-slurm.pref
Package: *
Pin: origin swx-repos.mtr.labs.mlnx
Pin-Priority: 750
EOF

apt-cache policy slurmd
apt-get -q update
apt-cache policy slurmd
apt-get -y install slurm-wlm slurm-wlm-basic-plugins slurmd slurm-client libpam-slurm



# To add check for result of previous command "even if error continue"
apt-get install libpam-slurm

function add_pam_slurm_row() {
  local file_path="/etc/pam.d/sshd"
  local new_row="account    required     pam_slurm.so"
  
  if grep -qF "$new_row" "$file_path"; then
    echo "Row already exists. Skipping..."
  else
    sed -i "/@include common-account/a $new_row" "$file_path"
    echo "Row added successfully."
  fi
}

function fix_slurm_fail_after_reboot() {
  local file_path="/lib/systemd/system/slurmd.service"
  local target="multi-user.target"
  sed -i "s/After=munge.service network.target remote-fs.target/After=munge.service network.target remote-fs.target $target/" "$file_path"
  systemctl daemon-reload
}

# Call the function to add the row
add_pam_slurm_row
fix_slurm_fail_after_reboot