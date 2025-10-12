#!/bin/bash
# Installation script for boot information display
# Run with: sudo bash install-bootinfo.sh

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Installing boot information display system..."
echo ""

# Create the bootinfo.sh script
echo "[1/5] Creating /usr/local/bin/bootinfo.sh..."
cat > /usr/local/bin/bootinfo.sh << 'EOF'
#!/bin/bash
# This script generates /etc/issue with system information

# Get hostname
HOSTNAME=$(hostname)

# Get primary IP address (first non-loopback IPv4)
IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

# If no IP found, show message
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="No network connection"
fi

# Generate the /etc/issue file
cat > /etc/issue << ISSUE

================================================================================
    System: $HOSTNAME
    IP Address: $IP_ADDRESS
================================================================================

ISSUE

EOF

# Make the script executable
chmod +x /usr/local/bin/bootinfo.sh
echo "✓ Created bootinfo.sh"

# Create systemd service
echo "[2/5] Creating systemd service..."
cat > /etc/systemd/system/bootinfo.service << 'EOF'
[Unit]
Description=Generate system information for pre-login screen
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bootinfo.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
echo "✓ Created bootinfo.service"

# Add to shell profile for terminal display
echo "[3/5] Adding to shell profiles..."
DISPLAY_CMD='
# Display system info in terminal
if [ -f /usr/local/bin/bootinfo.sh ]; then
    /usr/local/bin/bootinfo.sh > /tmp/.bootinfo 2>/dev/null
    [ -f /tmp/.bootinfo ] && cat /tmp/.bootinfo
fi
'

# Add to /etc/profile for all users
if ! grep -q "bootinfo.sh" /etc/profile 2>/dev/null; then
    echo "$DISPLAY_CMD" >> /etc/profile
fi

# Add to /etc/bash.bashrc for bash users
if [ -f /etc/bash.bashrc ]; then
    if ! grep -q "bootinfo.sh" /etc/bash.bashrc 2>/dev/null; then
        echo "$DISPLAY_CMD" >> /etc/bash.bashrc
    fi
fi

echo "✓ Added to shell profiles"

# Create systemd path unit to trigger on network changes
echo "[4/5] Creating systemd path monitor..."
cat > /etc/systemd/system/bootinfo.path << 'EOF'
[Unit]
Description=Monitor for network changes to update boot info

[Path]
PathModified=/sys/class/net

[Install]
WantedBy=multi-user.target
EOF
echo "✓ Created bootinfo.path"

# Reload systemd and enable services
echo "[5/6] Enabling services..."
systemctl daemon-reload
systemctl enable bootinfo.service >/dev/null 2>&1
systemctl enable bootinfo.path >/dev/null 2>&1
echo "✓ Services enabled for boot"

# Start services and generate initial display
echo "[6/6] Starting services..."
systemctl start bootinfo.service
systemctl start bootinfo.path
echo "✓ Services started"

echo ""
echo "============================================"
echo "Installation complete!"
echo "============================================"
echo ""
echo "Current boot information:"
echo ""
cat /etc/issue
echo ""
echo "This will display before login on:"
echo "  • Console (TTY)"
echo "  • SSH connections"
echo "  • Every time you open a terminal"
echo ""
echo "Useful commands:"
echo "  • View current display:  cat /etc/issue"
echo "  • Check service status:  systemctl status bootinfo.service"
echo "  • Manually update:       sudo /usr/local/bin/bootinfo.sh"
echo "  • Disable at boot:       sudo systemctl disable bootinfo.service bootinfo.path"
echo ""

# Delete the install script
SCRIPT_PATH="$(readlink -f "$0")"
echo "Cleaning up installation script..."
rm -f "$SCRIPT_PATH"
echo "✓ Installation script deleted"
echo ""
