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
# Generate system information display

# Get hostname
HOSTNAME=$(hostname)

# Get primary IP address - try multiple methods
# Method 1: Get IP from default route interface
IP_ADDRESS=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

# Method 2: If that fails, try getting any non-loopback IPv4
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(ip -4 addr show | grep -oP 'inet \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '127.0.0.1' | head -n1)
fi

# Method 3: Try hostname -I as fallback, filter for IPv4 only
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -oP '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
fi

# If still no IP found, show message
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="No IP detected"
fi

# Generate /etc/issue for TTY/console login
cat > /etc/issue << ISSUE

================================================================================
    System: $HOSTNAME
    IP Address: $IP_ADDRESS
================================================================================

ISSUE

EOF

chmod +x /usr/local/bin/bootinfo.sh
echo "✓ Created bootinfo.sh"

# Create systemd service
echo "[2/5] Creating systemd service..."
cat > /etc/systemd/system/bootinfo.service << 'EOF'
[Unit]
Description=Generate system information for login display
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

# Create systemd path unit to monitor network changes
echo "[3/4] Creating systemd path monitor..."
cat > /etc/systemd/system/bootinfo.path << 'EOF'
[Unit]
Description=Monitor for network changes to update boot info

[Path]
PathModified=/sys/class/net

[Install]
WantedBy=multi-user.target
EOF
echo "✓ Created bootinfo.path"

# Remove default issue files
rm -f /etc/issue.dpkg-dist /etc/issue.net.dpkg-dist 2>/dev/null

# Enable and start services
echo "[4/4] Enabling and starting services..."
systemctl daemon-reload
systemctl enable bootinfo.service >/dev/null 2>&1
systemctl enable bootinfo.path >/dev/null 2>&1
systemctl start bootinfo.service
systemctl start bootinfo.path
echo "✓ Services enabled and started"

echo ""
echo "============================================"
echo "Installation complete!"
echo "============================================"
echo ""
echo "Current system information:"
echo ""
cat /etc/issue
echo ""
echo "Display locations:"
echo "  • Console (TTY) - before username prompt"
echo ""
echo "Useful commands:"
echo "  • View display:          cat /etc/issue"
echo "  • Check service:         systemctl status bootinfo.service"
echo "  • Manually update:       sudo /usr/local/bin/bootinfo.sh"
echo "  • Disable at boot:       sudo systemctl disable bootinfo.service bootinfo.path"
echo ""

# Clean up installation directory
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
echo "Cleaning up installation files..."

if [[ "$SCRIPT_DIR" == *"/bootinfo"* ]] || [[ "$(basename "$SCRIPT_DIR")" == "bootinfo" ]]; then
    cd /tmp
    rm -rf "$SCRIPT_DIR"
    echo "✓ Deleted bootinfo directory"
else
    rm -f "$SCRIPT_PATH"
    echo "✓ Deleted installation script"
fi

echo ""
echo "Installation directory cleaned up successfully!"
