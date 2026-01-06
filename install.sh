#!/bin/bash
# =================================================
# XANMOD-X ULTIMATE VPN PANEL AUTO INSTALLER
# Complete Installation + Menu System
# =================================================

# Global variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

INSTALL_DIR="/etc/xanmod"
PANEL_SCRIPT="/usr/bin/xanmod-panel"
SERVICE_FILE="/etc/systemd/system/xanmod-panel.service"

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run as root!${NC}"
        echo -e "${YELLOW}Use: sudo -i or su root${NC}"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}[1/8] Installing dependencies...${NC}"
    
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y \
        curl wget nano git build-essential \
        net-tools iptables iptables-persistent \
        ufw fail2ban cron jq python3 python3-pip \
        openssl stunnel4 dropbear \
        screen htop iftop nload \
        unzip zip tar gzip
    
    # Install Node.js for some tools
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

# Function to install core VPN services
install_vpn_services() {
    echo -e "${YELLOW}[2/8] Installing VPN services...${NC}"
    
    # Install OpenVPN
    apt-get install -y openvpn easy-rsa
    cp -r /usr/share/easy-rsa/ /etc/openvpn/
    cd /etc/openvpn/easy-rsa
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa gen-req server nopass
    ./easyrsa sign-req server server
    ./easyrsa gen-dh
    
    # OpenVPN config
    cat > /etc/openvpn/server.conf << EOF
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log /var/log/openvpn/openvpn.log
verb 3
mute 20
explicit-exit-notify 1
EOF
    
    # Install BadVPN UDPGW
    wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw"
    chmod +x /usr/bin/badvpn-udpgw
    
    # Install Hysteria 1
    wget -O /usr/local/bin/hysteria1 "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
    chmod +x /usr/local/bin/hysteria1
    
    # Install Hysteria 2
    wget -O /usr/local/bin/hysteria2 "https://github.com/apernet/hysteria/releases/download/v2.2.2/hysteria-linux-amd64"
    chmod +x /usr/local/bin/hysteria2
    
    # Install UDP Custom
    wget -O /usr/local/bin/udp-custom "https://raw.githubusercontent.com/Exe302/Tunnel/main/udp-custom/udp-custom-linux-amd64"
    chmod +x /usr/local/bin/udp-custom
    
    # Install WebSocket Tunnel
    wget -O /usr/local/bin/ws-tunnel "https://github.com/erebe/wstunnel/releases/latest/download/wstunnel-linux-amd64"
    chmod +x /usr/local/bin/ws-tunnel
    
    echo -e "${GREEN}✅ VPN services installed${NC}"
}

# Function to configure services
configure_services() {
    echo -e "${YELLOW}[3/8] Configuring services...${NC}"
    
    # Create directories
    mkdir -p $INSTALL_DIR
    mkdir -p $INSTALL_DIR/users
    mkdir -p $INSTALL_DIR/backup
    mkdir -p $INSTALL_DIR/logs
    mkdir -p /etc/hysteria
    
    # Create user database
    cat > $INSTALL_DIR/users.db << EOF
# Format: username:password:expiry:limit:created
# Example: user1:pass1:2024-12-31:2:2023-01-01
EOF
    
    # Create Hysteria config
    cat > /etc/hysteria/config1.json << EOF
{
  "listen": ":36712",
  "cert": "/etc/hysteria/cert.pem",
  "key": "/etc/hysteria/key.pem",
  "obfs": "xanmod-secret",
  "up_mbps": 100,
  "down_mbps": 100,
  "resolver": "udp://1.1.1.1:53",
  "auth": {
    "mode": "external",
    "config": "/etc/hysteria/users.txt"
  }
}
EOF
    
    # Generate SSL certificate
    openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/key.pem
    openssl req -new -x509 -key /etc/hysteria/key.pem -out /etc/hysteria/cert.pem \
        -subj "/C=SG/CN=xanmod-server" -days 3650
    
    # Create UDP Custom config
    cat > /etc/udp-custom/config.json << EOF
{
  "servers": [
    {
      "listen": ":20800",
      "protocol": "udp",
      "obfs": "plain",
      "timeout": 300
    },
    {
      "listen": ":20801",
      "protocol": "udp", 
      "obfs": "zivpn",
      "timeout": 300
    },
    {
      "listen": ":20802",
      "protocol": "ws",
      "obfs": "plain",
      "timeout": 300
    },
    {
      "listen": ":20803",
      "protocol": "udp",
      "obfs": "udp-request",
      "timeout": 300
    }
  ],
  "users": []
}
EOF
    
    # Configure Dropbear (multi-port)
    cat > /etc/default/dropbear << EOF
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-p 109 -p 110 -p 442 -p 447"
DROPBEAR_BANNER="/etc/dropbear/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
    
    # Configure Stunnel
    cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
verify = 2
CAfile = /etc/stunnel/cert.pem
client = no

[dropbear]
accept = 990
connect = 127.0.0.1:442
EOF
    
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=SG/ST=Singapore/L=Singapore/O=XANMOD/CN=server.xanmod" \
        -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem
    
    echo -e "${GREEN}✅ Services configured${NC}"
}

# Function to create panel script
create_panel_script() {
    echo -e "${YELLOW}[4/8] Creating panel script...${NC}"
    
    # Download main panel script
    wget -O $PANEL_SCRIPT "https://raw.githubusercontent.com/xanmodx/xanmod-panel/main/xanmod-panel.sh"
    
    # If download fails, create from here
    if [ ! -f $PANEL_SCRIPT ]; then
        cat > $PANEL_SCRIPT << 'EOF'
#!/bin/bash
# XANMOD PANEL MAIN SCRIPT
# Placeholder - actual script will be loaded from GitHub
echo "XANMOD Panel loading..."
wget -O /tmp/xanmod-panel-main.sh "https://raw.githubusercontent.com/xanmodx/xanmod-panel/main/main.sh"
bash /tmp/xanmod-panel-main.sh
EOF
    fi
    
    chmod +x $PANEL_SCRIPT
    
    # Create systemd service
    cat > $SERVICE_FILE << EOF
[Unit]
Description=XANMOD VPN Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/xanmod
ExecStart=/usr/bin/xanmod-panel
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=xanmod-panel

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xanmod-panel
    
    echo -e "${GREEN}✅ Panel script created${NC}"
}

# Function to install web tools
install_web_tools() {
    echo -e "${YELLOW}[5/8] Installing web tools...${NC}"
    
    # Install FileBrowser
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
    filebrowser config init -d /etc/filebrowser.db
    filebrowser config set --auth.method=noauth \
        --port=8888 \
        --address=0.0.0.0 \
        --root=/ \
        -d /etc/filebrowser.db
    
    # Create FileBrowser service
    cat > /etc/systemd/system/filebrowser.service << EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/filebrowser -d /etc/filebrowser.db
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable filebrowser
    
    # Install Webmin
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    wget -qO - https://download.webmin.com/jcameron-key.asc | apt-key add -
    apt-get update
    apt-get install -y webmin
    
    echo -e "${GREEN}✅ Web tools installed${NC}"
}

# Function to optimize system
optimize_system() {
    echo -e "${YELLOW}[6/8] Optimizing system...${NC}"
    
    # Create swap file
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Optimize sysctl
    cat > /etc/sysctl.d/99-xanmod-optimize.conf << EOF
# Network optimizations
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3

# TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP options
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5

# IPv6 optimizations
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-xanmod-optimize.conf
    
    # Configure firewall
    ufw --force disable
    ufw --force reset
    
    ufw default deny incoming
    ufw default allow outgoing
    
    # Open required ports
    PORTS="22 109 110 442 447 990 1194 36712 8443 20800 20801 20802 20803 20806 8888 10000 80 443 53 7300"
    for PORT in $PORTS; do
        ufw allow $PORT/tcp
        ufw allow $PORT/udp
    done
    
    ufw --force enable
    
    # Enable BBR
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    
    echo -e "${GREEN}✅ System optimized${NC}"
}

# Function to create startup script
create_startup_script() {
    echo -e "${YELLOW}[7/8] Creating startup script...${NC}"
    
    cat > /etc/xanmod/start-services.sh << 'EOF'
#!/bin/bash
# XANMOD Startup Script

echo "[$(date)] Starting XANMOD services..."

# Start core services
systemctl start ssh
systemctl start dropbear
systemctl start stunnel4
systemctl start openvpn@server

# Start BadVPN UDPGW
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500

# Start Hysteria
/usr/local/bin/hysteria1 -config /etc/hysteria/config1.json server &
/usr/local/bin/hysteria2 server -c /etc/hysteria/config2.json &

# Start UDP Custom
/usr/local/bin/udp-custom -config /etc/udp-custom/config.json &

# Start WebSocket Tunnel
/usr/local/bin/ws-tunnel server --server ws://0.0.0.0:20806 --upstream tcp://127.0.0.1:20800 &

# Start web tools
systemctl start filebrowser
systemctl start webmin

echo "[$(date)] All services started!"
EOF
    
    chmod +x /etc/xanmod/start-services.sh
    
    # Add to crontab for auto-start
    (crontab -l 2>/dev/null; echo "@reboot /etc/xanmod/start-services.sh") | crontab -
    
    # Create auto-update script
    cat > /etc/xanmod/auto-update.sh << 'EOF'
#!/bin/bash
# Auto-update script
apt-get update -y
apt-get upgrade -y --allow-downgrades
apt-get autoremove -y
apt-get autoclean -y

# Update panel script
wget -O /tmp/xanmod-panel-update.sh "https://raw.githubusercontent.com/xanmodx/xanmod-panel/main/update.sh"
if [ -f /tmp/xanmod-panel-update.sh ]; then
    bash /tmp/xanmod-panel-update.sh
fi

# Restart services
systemctl restart xanmod-panel
EOF
    
    chmod +x /etc/xanmod/auto-update.sh
    
    # Schedule weekly updates
    (crontab -l 2>/dev/null; echo "0 3 * * 0 /etc/xanmod/auto-update.sh >> /var/log/xanmod-update.log 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Startup scripts created${NC}"
}

# Function to create management panel
create_management_panel() {
    echo -e "${YELLOW}[8/8] Creating management panel...${NC}"
    
    # Create the main panel menu script
    cat > /usr/local/bin/xanmod << 'EOF'
#!/bin/bash
# XANMOD Management Panel

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Get server info
get_info() {
    IP=$(curl -s ifconfig.me)
    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p)
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    MEM=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    DISK=$(df -h / | awk 'NR==2{printf "%s", $5}')
}

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║      XANMOD-X ULTIMATE VPN PANEL            ║"
    echo "║      Multi-Protocol Server Management       ║"
    echo "╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Server IP  : ${WHITE}$IP"
    echo -e "${CYAN}Hostname   : ${WHITE}$HOSTNAME"
    echo -e "${CYAN}Uptime     : ${WHITE}$UPTIME"
    echo -e "${CYAN}Load       : ${WHITE}$LOAD"
    echo -e "${CYAN}Memory     : ${WHITE}$MEM"
    echo -e "${CYAN}Disk Usage : ${WHITE}$DISK${NC}"
    echo ""
}

show_menu() {
    echo -e "${GREEN}MAIN MENU${NC}"
    echo ""
    echo -e "  ${WHITE}[1]${NC} User Management"
    echo -e "  ${WHITE}[2]${NC} Service Control"
    echo -e "  ${WHITE}[3]${NC} Server Monitoring"
    echo -e "  ${WHITE}[4]${NC} Backup & Restore"
    echo -e "  ${WHITE}[5]${NC} Speed Test"
    echo -e "  ${WHITE}[6]${NC} Configuration"
    echo -e "  ${WHITE}[7]${NC} Web Tools"
    echo -e "  ${WHITE}[8]${NC} Firewall/Rules"
    echo -e "  ${WHITE}[9]${NC} System Info"
    echo ""
    echo -e "  ${WHITE}[0]${NC} Exit"
    echo ""
}

user_management() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════╗"
        echo -e "║           USER MANAGEMENT               ║"
        echo -e "╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${WHITE}[1]${NC} Create User"
        echo -e "  ${WHITE}[2]${NC} Delete User"
        echo -e "  ${WHITE}[3]${NC} Renew User"
        echo -e "  ${WHITE}[4]${NC} List Users"
        echo -e "  ${WHITE}[5]${NC} User Details"
        echo -e "  ${WHITE}[6]${NC} Online Users"
        echo -e "  ${WHITE}[7]${NC} Back to Main"
        echo ""
        read -p "Select option: " opt
        
        case $opt in
            1) create_user ;;
            2) delete_user ;;
            3) renew_user ;;
            4) list_users ;;
            5) user_details ;;
            6) online_users ;;
            7) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

create_user() {
    echo ""
    read -p "Username: " user
    read -sp "Password: " pass
    echo
    read -p "Expiry days: " days
    
    expiry=$(date -d "+$days days" +%Y-%m-%d)
    
    # Add to database
    echo "$user:$pass:$expiry:0:$(date +%Y-%m-%d)" >> /etc/xanmod/users.db
    
    # Add to Hysteria
    echo "$user:$pass" >> /etc/hysteria/users.txt
    
    echo ""
    echo -e "${GREEN}✅ User created successfully!${NC}"
    echo ""
    echo -e "${YELLOW}=== CONNECTION INFO ===${NC}"
    echo -e "Host: $IP"
    echo -e "Ports: SSH(22,109,110,442,447) SSL(990) Hysteria(36712) UDP(20800-20803) WS(20806)"
    echo -e "Username: $user"
    echo -e "Password: $pass"
    echo -e "Expiry: $expiry"
    echo ""
    read -p "Press Enter to continue..."
}

list_users() {
    echo ""
    echo -e "${YELLOW}=== USER LIST ===${NC}"
    echo ""
    printf "%-15s %-12s %-10s\n" "Username" "Expiry" "Status"
    echo "----------------------------------------"
    
    while IFS=: read -r user pass expiry limit created; do
        if [[ "$expiry" > "$(date +%Y-%m-%d)" ]]; then
            status="${GREEN}ACTIVE${NC}"
        else
            status="${RED}EXPIRED${NC}"
        fi
        printf "%-15s %-12s %-10s\n" "$user" "$expiry" "$status"
    done < /etc/xanmod/users.db
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        get_info
        show_banner
        show_menu
        
        read -p "Select option: " choice
        
        case $choice in
            1) user_management ;;
            2) 
                echo -e "${YELLOW}Starting all services...${NC}"
                /etc/xanmod/start-services.sh
                sleep 2
                ;;
            3)
                echo -e "${YELLOW}Server monitoring...${NC}"
                htop
                ;;
            4)
                echo -e "${YELLOW}Backup system...${NC}"
                tar -czf /backup/xanmod-backup-$(date +%Y%m%d).tar.gz /etc/xanmod /etc/hysteria /etc/udp-custom
                echo -e "${GREEN}Backup created!${NC}"
                sleep 2
                ;;
            5)
                echo -e "${YELLOW}Running speed test...${NC}"
                speedtest-cli --simple
                sleep 5
                ;;
            6)
                nano /etc/xanmod/users.db
                ;;
            7)
                echo -e "${YELLOW}Web Tools:${NC}"
                echo -e "FileBrowser: http://$IP:8888"
                echo -e "Webmin: https://$IP:10000"
                sleep 5
                ;;
            8)
                ufw status verbose
                sleep 5
                ;;
            9)
                echo -e "${YELLOW}System Information:${NC}"
                neofetch
                sleep 5
                ;;
            0)
                echo -e "${YELLOW}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main
EOF
    
    chmod +x /usr/local/bin/xanmod
    
    # Create alias
    echo "alias xanmod='/usr/local/bin/xanmod'" >> /root/.bashrc
    source /root/.bashrc
    
    echo -e "${GREEN}✅ Management panel created${NC}"
}

# Function to display final instructions
show_final_instructions() {
    clear
    IP=$(curl -s ifconfig.me)
    
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         XANMOD-X INSTALLATION COMPLETE!             ║"
    echo "╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✅ Installation successful!${NC}"
    echo ""
    echo -e "${YELLOW}=== SERVER INFORMATION ===${NC}"
    echo -e "IP Address  : $IP"
    echo -e "Hostname    : $(hostname)"
    echo ""
    echo -e "${YELLOW}=== SERVICES PORTS ===${NC}"
    echo -e "SSH         : 22, 109, 110, 442, 447"
    echo -e "SSL/TLS     : 990"
    echo -e "Hysteria 1  : 36712"
    echo -e "Hysteria 2  : 8443"
    echo -e "UDP Custom  : 20800 (plain), 20801 (zivpn), 20802 (ws), 20803 (udp-request)"
    echo -e "WebSocket   : 20806"
    echo -e "OpenVPN     : 1194"
    echo -e "BadVPN UDPGW: 7300"
    echo ""
    echo -e "${YELLOW}=== WEB TOOLS ===${NC}"
    echo -e "FileBrowser : http://$IP:8888"
    echo -e "Webmin      : https://$IP:10000"
    echo ""
    echo -e "${YELLOW}=== MANAGEMENT ===${NC}"
    echo -e "Panel Command: xanmod"
    echo -e "Start Services: /etc/xanmod/start-services.sh"
    echo ""
    echo -e "${YELLOW}=== QUICK START ===${NC}"
    echo -e "1. Run 'xanmod' to open management panel"
    echo -e "2. Select [1] User Management"
    echo -e "3. Create your first user"
    echo -e "4. Use the connection info for ZiVPN/HTTP Injector"
    echo ""
    echo -e "${GREEN}=== ZIVPN CONFIG ===${NC}"
    echo -e "Host: $IP:20801"
    echo -e "Protocol: UDP"
    echo -e "OBFS: zivpn"
    echo -e "Method: chacha20-ietf-poly1305"
    echo ""
    echo -e "${RED}=== IMPORTANT ===${NC}"
    echo -e "1. Change default passwords!"
    echo -e "2. Enable firewall (ufw)"
    echo -e "3. Regular updates: apt update && apt upgrade"
    echo -e "4. Backup configs regularly"
    echo ""
    echo -e "${YELLOW}Rebooting in 10 seconds...${NC}"
    echo -e "${CYAN}After reboot, login and type 'xanmod'${NC}"
    
    sleep 10
    reboot
}

# Main installation function
main_install() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║      XANMOD-X ULTIMATE VPN INSTALLER        ║"
    echo "║      Complete Multi-Protocol Server         ║"
    echo "╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    
    # Start installation
    install_dependencies
    install_vpn_services
    configure_services
    create_panel_script
    install_web_tools
    optimize_system
    create_startup_script
    create_management_panel
    
    # Start services
    systemctl start xanmod-panel
    /etc/xanmod/start-services.sh
    
    show_final_instructions
}

# Run installation
main_install
