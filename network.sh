#!/bin/bash

# Force standard locale for global compatibility
export LC_ALL=C
export LANG=C

# Required Packages for Network Analysis
PACKAGES="dialog net-tools iproute2 util-linux procps-ng"

install_deps() {
    echo "Checking network tools..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog net-tools iproute procps
    fi
}

# Uninstall & Exit (Frame Rule)
uninstall_all() {
    clear
    echo "Uninstalling network tools and cleaning system..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf remove -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get remove -y dialog net-tools iproute procps
        sudo apt-get autoremove -y
    fi
    rm -rf "$TEMP_DIR"
    echo "Network Dashboard closed. Goodbye Boss!"
    sleep 1
}

! command -v dialog &> /dev/null && install_deps

TEMP_DIR="/tmp/net_dashboard"
mkdir -p $TEMP_DIR
TEMP_OUT="$TEMP_DIR/net_output.txt"

# --- Analysis Functions ---

show_interfaces() {
    {
        echo "NETWORK INTERFACES (IP Addresses & Status)"
        echo "------------------------------------------"
        ip -4 -br addr show
        echo -e "\nINTERFACE STATISTICS"
        echo "------------------------------------------"
        ip -s link
    } > "$TEMP_OUT"
}

show_listening() {
    {
        echo "LISTENING PORTS (TCP/UDP)"
        echo "------------------------------------------------------------"
        echo "PROTO  RECV-Q  SEND-Q  LOCAL ADDRESS         PID/PROGRAM NAME"
        ss -tulpn | grep LISTEN | column -t
    } > "$TEMP_OUT"
}

show_connections() {
    {
        echo "ESTABLISHED CONNECTIONS (Active Traffic)"
        echo "------------------------------------------------------------"
        ss -tunpa | grep ESTAB | column -t
    } > "$TEMP_OUT"
}

show_routes() {
    {
        echo "ROUTING TABLE & GATEWAY"
        echo "------------------------------------------"
        ip route show | column -t
        echo -e "\nDNS RESOLVERS (Nameservers)"
        echo "------------------------------------------"
        cat /etc/resolv.conf | grep nameserver
    } > "$TEMP_OUT"
}

# --- Main Dashboard Loop ---
while true; do
    HEIGHT=$(tput lines); WIDTH=$(tput cols)
    
    CHOICE=$(dialog --clear --backtitle "Network Dashboard v1.0" --title "NETWORK CONTROL CENTER" \
        --menu "Select a Network Analysis Module:" 18 70 8 \
        "1" "NIC INFO (Interfaces, IPs, Stats)" \
        "2" "LISTEN PORTS (What's open?)" \
        "3" "ACTIVE CONNS (Real-time traffic)" \
        "4" "ROUTES & DNS (Gateway and Resolvers)" \
        "5" "PUBLIC IP (Check external visibility)" \
        "6" "PING TEST (Check Google/Cloudflare)" \
        "X" "UNINSTALL TOOLS & EXIT" \
        "Q" "EXIT WITHOUT UNINSTALL" 2>&1 >/dev/tty)

    [ -z "$CHOICE" ] || [ "$CHOICE" == "Q" ] && { rm -rf "$TEMP_DIR"; clear; break; }
    
    if [ "$CHOICE" == "X" ]; then uninstall_all; break; fi

    case $CHOICE in
        1) show_interfaces ;;
        2) show_listening ;;
        3) show_connections ;;
        4) show_routes ;;
        5) curl -s https://ifconfig.me > "$TEMP_OUT" && echo -e "\nYour Public IP: $(cat $TEMP_OUT)" > "$TEMP_OUT" ;;
        6) ping -c 4 8.8.8.8 > "$TEMP_OUT" ;;
    esac

    # Show Output in Textbox
    dialog --title "Analysis Result: Option $CHOICE" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
done

rm -rf "$TEMP_DIR"
