#!/bin/bash

#--------------------------------------------------------------------
# Script to Install Prometheus Node Exporter on Linux (Ubuntu & RHEL)
#--------------------------------------------------------------------
NODE_EXPORTER_VERSION="1.8.2"
NODE_EXPORTER_BINARY="/usr/bin/node_exporter"

# Check if Node Exporter is already installed
if [ -f "$NODE_EXPORTER_BINARY" ]; then
  INSTALLED_VERSION=$($NODE_EXPORTER_BINARY --version 2>/dev/null | grep "version" | awk '{print $3}')
  echo "Node Exporter is already installed. Current version: $INSTALLED_VERSION"
  exit 0
fi

echo "Installing Prometheus Node Exporter version $NODE_EXPORTER_VERSION..."

# Download and Extract Node Exporter
cd /tmp || exit
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
if [ $? -ne 0 ]; then
  echo "Failed to download Node Exporter. Exiting."
  exit 1
fi

tar xvfz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
cd node_exporter-$NODE_EXPORTER_VERSION.linux-amd64 || exit

# Move Binary to /opt and Create Symlink
mkdir -p /opt/node_exporter
mv node_exporter /opt/node_exporter/
ln -sf /opt/node_exporter/node_exporter "$NODE_EXPORTER_BINARY"
rm -rf /tmp/node_exporter*

# Create Dedicated User
if ! id "node_exporter" &>/dev/null; then
  useradd -rs /bin/false node_exporter
fi

chown -R node_exporter:node_exporter /opt/node_exporter

# Create Systemd Service
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=$NODE_EXPORTER_BINARY

[Install]
WantedBy=multi-user.target
EOF

# Reload Systemd, Start, and Enable Service
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Check Service Status
if systemctl is-active --quiet node_exporter; then
  echo "Node Exporter was successfully installed and is running."
else
  echo "Node Exporter installation failed. Check the service logs for details."
  exit 1
fi

# Check Installed Version
INSTALLED_VERSION=$($NODE_EXPORTER_BINARY --version 2>/dev/null | grep "version" | awk '{print $3}')
if [ "$INSTALLED_VERSION" == "$NODE_EXPORTER_VERSION" ]; then
  echo "Node Exporter version $INSTALLED_VERSION installed successfully."
else
  echo "Warning: Installed version ($INSTALLED_VERSION) does not match expected version ($NODE_EXPORTER_VERSION)."
fi

# Configure Firewall
if command -v firewall-cmd &>/dev/null; then
  echo "Configuring firewall using firewalld (port 9100)..."
  firewall-cmd --permanent --add-port=9100/tcp
  firewall-cmd --reload
elif command -v ufw &>/dev/null; then
  echo "Configuring firewall using ufw (port 9100)..."
  ufw allow 9100
fi

# Handle SELinux
if command -v getenforce &>/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
  echo "Setting SELinux context for Node Exporter..."
  chcon -t bin_t /opt/node_exporter/node_exporter
fi

echo "Node Exporter setup complete!"

