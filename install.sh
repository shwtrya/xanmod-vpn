#!/bin/bash
# XANMOD VPN Ultimate Installer
# Install with: bash <(curl -s https://raw.githubusercontent.com/username/xanmod-vpn/main/install.sh)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BANNER="${BLUE}
╔══════════════════════════════════════════════╗
║       XANMOD VPN ULTIMATE INSTALLER          ║
║       Multi-Protocol VPN Server              ║
╚══════════════════════════════════════════════╝${NC}"

echo -e "$BANNER"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Check OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Cannot detect OS${NC}"
    exit 1
fi

# Installation function
install_xanmod() {
    echo -e "${YELLOW}[1/5] Updating system...${NC}"
    apt-get update
    apt-get upgrade -y
    
    echo -e "${YELLOW}[2/5] Installing dependencies...${NC}"
    apt-get install -y curl wget git nano jq ufw fail2ban cron python3 python3-pip
    
    echo -e "${YELLOW}[3/5] Downloading XANMOD scripts...${NC}"
    mkdir -p /etc/xanmod
    wget -O /usr/local/bin/xanmod https://raw.githubusercontent.com/$GITHUB_USER/xanmod-vpn/main/xanmod.sh
    chmod +x /usr/local/bin/xanmod
    
    wget -O /etc/xanmod/menu.sh https://raw.githubusercontent.com/$GITHUB_USER/xanmod-vpn/main/menu.sh
    chmod +x /etc/xanmod/menu.sh
    
    echo -e "${YELLOW}[4/5] Setting up services...${NC}"
    # Create systemd service
    cat > /etc/systemd/system/xanmod.service << EOF
[Unit]
Description=XANMOD VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/xanmod start
ExecStop=/usr/local/bin/xanmod stop
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xanmod.service
    
    echo -e "${YELLOW}[5/5] Configuring firewall...${NC}"
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80,443/tcp
    ufw allow 36712/udp
    ufw allow 8443/tcp
    ufw allow 20800:20810/udp
    ufw --force enable
    
    echo -e "${GREEN}Installation completed!${NC}"
    echo ""
    echo -e "${YELLOW}Quick commands:${NC}"
    echo "  Start:   systemctl start xanmod"
    echo "  Stop:    systemctl stop xanmod"
    echo "  Menu:    xanmod menu"
    echo "  Status:  xanmod status"
    echo ""
    echo -e "${GREEN}Run 'xanmod menu' to start configuring.${NC}"
}

# Main menu
main_menu() {
    echo -e "${YELLOW}Select action:${NC}"
    echo "1) Install XANMOD VPN Server"
    echo "2) Update existing installation"
    echo "3) Uninstall"
    echo "4) Exit"
    echo ""
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            GITHUB_USER="shwtrya"  # GANTI INI!
            install_xanmod
            ;;
        2)
            echo -e "${YELLOW}Updating...${NC}"
            wget -O /usr/local/bin/xanmod https://raw.githubusercontent.com/$GITHUB_USER/xanmod-vpn/main/xanmod.sh
            chmod +x /usr/local/bin/xanmod
            systemctl restart xanmod
            echo -e "${GREEN}Updated!${NC}"
            ;;
        3)
            echo -e "${RED}Uninstalling...${NC}"
            systemctl stop xanmod
            systemctl disable xanmod
            rm -f /usr/local/bin/xanmod
            rm -rf /etc/xanmod
            rm -f /etc/systemd/system/xanmod.service
            echo -e "${GREEN}Uninstalled!${NC}"
            ;;
        4)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

main_menu
