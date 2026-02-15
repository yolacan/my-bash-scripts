#!/bin/bash

# Force standard locale
export LC_ALL=C
export LANG=C

# Required Packages
PACKAGES="dialog util-linux procps-ng"

# Dependency Check & Auto-Install
install_deps() {
    echo "Checking dependencies..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog util-linux procps
    fi
}

# Uninstall Function
uninstall_all() {
    clear
    echo "Cleaning system..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf remove -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get remove -y dialog util-linux procps
        sudo apt-get autoremove -y
    fi
    rm -rf "$TEMP_DIR"
    echo "System is clean. Goodbye Boss!"
    sleep 1
}

! command -v dialog &> /dev/null && install_deps

TEMP_DIR="/tmp/svc_manager_v1.1"
mkdir -p $TEMP_DIR
TEMP_OUT="$TEMP_DIR/output.txt"
SVC_LIST="$TEMP_DIR/services.txt"

# --- Management Menu ---
manage_service() {
    local svc=$1
    while true; do
        HEIGHT=$(tput lines)
        WIDTH=$(tput cols)
        ACTION=$(dialog --clear --title "Control Center: $svc" \
            --menu "Manage $svc:" 18 65 8 \
            "1" "Status (Detailed View)" \
            "2" "Restart Service" \
            "3" "Stop Service" \
            "4" "Start Service" \
            "5" "Enable Service (On Boot)" \
            "6" "Disable Service (Manual Only)" \
            "7" "View Recent Logs (n 50)" \
            "8" "Live Stream Logs (-f)" \
            "B" "<< Back to List" 2>&1 >/dev/tty)

        [ -z "$ACTION" ] || [ "$ACTION" == "B" ] && break

        case $ACTION in
            1) systemctl status "$svc" --no-pager > "$TEMP_OUT" 2>&1 ;;
            2) systemctl restart "$svc" && echo "SUCCESS: Restarted." > "$TEMP_OUT" 2>&1 ;;
            3) systemctl stop "$svc" && echo "SUCCESS: Stopped." > "$TEMP_OUT" 2>&1 ;;
            4) systemctl start "$svc" && echo "SUCCESS: Started." > "$TEMP_OUT" 2>&1 ;;
            5) systemctl enable "$svc" && echo "SUCCESS: Enabled." > "$TEMP_OUT" 2>&1 ;;
            6) systemctl disable "$svc" && echo "SUCCESS: Disabled." > "$TEMP_OUT" 2>&1 ;;
            7) journalctl -u "$svc" -n 50 --no-pager > "$TEMP_OUT" 2>&1 ;;
            8) clear; echo "Streaming $svc logs (CTRL+C to stop)..."; sleep 1; journalctl -u "$svc" -f; continue ;;
        esac
        dialog --title "Result: $svc" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
    done
}

# --- Main Loop ---
while true; do
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    
    # Category Selection
    CAT=$(dialog --clear --backtitle "Service Manager v1.1" --title "Main Menu" \
        --menu "Select service filter:" 15 60 5 \
        "ACTIVE" "Show only running services" \
        "ALL"    "Show all services (Active & Inactive)" \
        "X"      "UNINSTALL TOOLS & EXIT" \
        "Q"      "JUST EXIT" 2>&1 >/dev/tty)

    [ -z "$CAT" ] || [ "$CAT" == "Q" ] && { rm -rf "$TEMP_DIR"; clear; break; }
    if [ "$CAT" == "X" ]; then uninstall_all; break; fi

    # Fetch Services based on category
    if [ "$CAT" == "ACTIVE" ]; then
        systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1 " [running]"}' > "$SVC_LIST"
    else
        systemctl list-units --type=service --all --no-pager --no-legend | awk '{print $1 " [" $4 "]"}' > "$SVC_LIST"
    fi

    MENU_ITEMS=()
    while read -r name status; do
        MENU_ITEMS+=("$name" "$status")
    done < "$SVC_LIST"
    
    SELECTED_SVC=$(dialog --clear --title "$CAT Services" \
        --menu "Select a service:" $HEIGHT $WIDTH $((HEIGHT - 10)) \
        "${MENU_ITEMS[@]}" "B" "<< BACK TO CATEGORIES" 2>&1 >/dev/tty)

    [ -z "$SELECTED_SVC" ] || [ "$SELECTED_SVC" == "B" ] && continue

    manage_service "$SELECTED_SVC"
done

rm -rf "$TEMP_DIR"
