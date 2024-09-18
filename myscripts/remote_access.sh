#!/bin/bash -E

set -Evx -o pipefail

REMOTE_USER="root"
REMOTE_HOST="swx-snap2"
REMOTE_IP="10.209.226.151"  # This should be the IP address of the remote host

# Initial steps on the remote host
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    set -eEvx -o pipefail
    echo "Starting initial steps..."
    sudo yum install -y mutt
    sudo reboot
EOF

# Wait for the remote host to shut down
echo "Waiting for the remote host to shut down..."
sleep 20

# Wait for the remote host to come back online
echo "Waiting for the remote host to come back online..."
while ! ping -c 1 -W 5 "$REMOTE_IP"; do
    echo "Waiting for the remote host to come back online..."
    sleep 5
done

# Ensure SSH is available before proceeding
echo "Waiting for SSH to become available..."
while ! nc -zv $REMOTE_IP 22; do
    echo "Waiting for SSH service to become available..."
    sleep 5
done

# Ensure services are fully up
echo "Waiting for services to be fully up..."
sleep 30

# Continue with the rest of the steps on the remote host
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    set -eEvx -o pipefail
    echo "Continuing with the rest of the steps..."
    sudo yum install -y vim
    echo "Script completed successfully."
EOF

