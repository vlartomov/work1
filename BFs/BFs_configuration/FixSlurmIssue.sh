#!/bin/bash

set -xvEe -o pipefail

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
  systemctl restart slurmd

}

# Call the function to add the row
add_pam_slurm_row
fix_slurm_fail_after_reboot
