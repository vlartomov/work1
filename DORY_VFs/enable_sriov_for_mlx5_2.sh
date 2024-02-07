#!/bin/bash

# Create enable_sriov.sh
echo '#!/bin/bash
echo 2 > /sys/class/infiniband/mlx5_0/device/sriov_numvfs' > /usr/local/bin/enable_sriov.sh

# Make it executable
chmod u+x /usr/local/bin/enable_sriov.sh

# Create systemd service file
echo '[Unit]
Description=Enable SR-IOV
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/enable_sriov.sh

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/enable_sriov.service

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable enable_sriov
systemctl start enable_sriov

