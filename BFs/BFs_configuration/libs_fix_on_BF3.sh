#!/bin/bash

set -xvEe -o pipefail

HNAME=$1

function remove_all_unecessary_files() {
  directory="/etc/libibverbs.d"

  # Go to the target directory
  cd "$directory" || exit

  # Remove all files except for "mlx5.driver"
  find . ! -name "mlx5.driver" -type f -exec rm -f {} +
}

sshpass -p "3tango" ssh root@$HNAME "$(declare -f remove_all_unecessary_files); remove_all_unecessary_files"

function remove_all_unecessary_files() {

  directory="/etc/libibverbs.d"

  # Go to the target directory
  cd "$directory" || exit

  # Remove all files except for "mlx5.driver"
  find . ! -name "mlx5.driver" -type f -exec rm -f {} +
}
