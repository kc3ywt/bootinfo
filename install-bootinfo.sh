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
echo "[1/6] Creating /usr/local/bin/bootinfo.sh..."
cat > /usr/local/bin/bootinfo.sh << 'EOF'
#!/bin/bash
# Generate system information display

# Get hostname
HOSTNAME=$(hostname)

# Get primary IP address (first non-loopback IPv4)
IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

# If no IP found, show message
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="No network connection"
fi

# Generate /etc/issue for TTY/console login
cat > /etc/issue << ISSUE

================================================================================
    System: $HOSTNAME
    IP Address: $IP_ADDRESS
================================================================================

ISSUE

# Generate /etc/issue.net for SSH pre-authentication banner
cat > /etc/issue.net << ISSUE

================================================================================
    System: $HOSTNAME
    IP Address: $IP_ADDRESS
================================================================================

ISSUE

EOF

chmod +x /usr/local/bin/bootinfo.sh
echo "✓ Created bootinfo.sh"

# Create systemd service
echo "[2/6] Creating systemd service..."
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

# Add to shell profile for terminal display
echo "[3/6] Adding to shell profiles..."
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

# Create systemd path unit to monitor network changes
echo "[4/6] Creating systemd path monitor..."
cat > /etc/systemd/system/bootinfo.path << 'EOF'
[Unit]
Description=Monitor for network changes to update boot info

[Path]
PathModified=/sys/class/net

[Install]
WantedBy=multi-user.target
EOF
echo "✓ Created bootinfo.path"

# Configure SSH to display banner
echo "[5/6] Configuring SSH banner..."
if [ -f /etc/ssh/sshd_config ]; then
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # Remove any existing Banner and DebianBanner lines
    sed -i '/^#\?Banner/d' /etc/ssh/sshd_config
    sed -i '/^#\?DebianBanner/d' /etc/ssh/sshd_config
    
    # Add our configuration
    cat >> /etc/ssh/sshd_config << 'SSHEOF'

# Boot info banner configuration
Banner /etc/issue.net
DebianBanner no
SSHEOF
    
    # Test SSH config before restarting
    if sshd -t 2>/dev/null; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        echo "✓ SSH configured and restarted"
    else
        echo "⚠ SSH config test failed, skipping SSH configuration"
    fi
else
    echo "⚠ SSH config not found, skipping SSH configuration"
fi

# Remove default issue files
rm -f /etc/issue.dpkg-dist /etc/issue.net.dpkg-dist 2>/dev/null

# Enable and start services
echo "[6/6] Enabling and starting services..."
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
echo "  • SSH login - after username, before password"
echo "  • Terminal - when opening new shell session"
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
