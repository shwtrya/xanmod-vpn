#!/bin/bash
# XANMOD VPN Main Script

case "$1" in
    start)
        echo "Starting XANMOD VPN..."
        # Start services here
        systemctl start ssh
        systemctl start hysteria
        echo "Started!"
        ;;
    stop)
        echo "Stopping XANMOD VPN..."
        # Stop services here
        systemctl stop hysteria
        echo "Stopped!"
        ;;
    menu)
        /etc/xanmod/menu.sh
        ;;
    status)
        echo "=== XANMOD VPN Status ==="
        systemctl status xanmod.service --no-pager
        echo ""
        echo "Active connections:"
        netstat -tulpn | grep -E '(36712|8443|20800)'
        ;;
    add-user)
        if [ -z "$4" ]; then
            echo "Usage: xanmod add-user <username> <password> <days>"
            exit 1
        fi
        echo "Creating user $2..."
        # Add user logic here
        echo "$2:$3:$(date -d "+$4 days" +"%Y-%m-%d")" >> /etc/xanmod/users.txt
        echo "User $2 created!"
        ;;
    backup)
        echo "Backing up..."
        tar -czf /backup/xanmod-$(date +%Y%m%d).tar.gz /etc/xanmod/
        echo "Backup saved to /backup/"
        ;;
    *)
        echo "XANMOD VPN Manager"
        echo "Commands:"
        echo "  start       - Start all services"
        echo "  stop        - Stop all services"
        echo "  menu        - Interactive menu"
        echo "  status      - Show server status"
        echo "  add-user    - Create new user"
        echo "  backup      - Backup configuration"
        ;;
esac