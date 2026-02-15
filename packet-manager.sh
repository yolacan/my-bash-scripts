#!/bin/bash

export LC_ALL=C
export LANG=C

PACKAGES="dialog util-linux grep awk"

install_deps() {
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog util-linux
    fi
}

! command -v dialog &> /dev/null && install_deps

TEMP_DIR="/tmp/pkg_manager_v1.1"
mkdir -p $TEMP_DIR
PKG_LIST="$TEMP_DIR/pkgs.txt"
INFO_OUT="$TEMP_DIR/info.txt"

# --- Smart Filtering Logic ---
get_filtered_list() {
    local filter=$1
    case $filter in
        "SERVICES")
            # Filter packages that have .service files
            if [ -f /etc/redhat-release ]; then
                rpm -qa --queryformat '%{NAME}\n' | grep -E "docker|nginx|httpd|mysql|ssh|postfix|chrony" > "$PKG_LIST"
            else
                dpkg-query -W -f='${Package}\n' | grep -E "docker|nginx|apache|mysql|ssh|postfix" > "$PKG_LIST"
            fi
            ;;
        "SECURITY")
            grep -E "audit|policy|selinux|firewall|fail2ban|iptables|sudo|openssl" "$TEMP_DIR/all_pkgs.txt" > "$PKG_LIST"
            ;;
        "SYSTEM")
            grep -E "kernel|systemd|libc|bash|coreutils|grub" "$TEMP_DIR/all_pkgs.txt" > "$PKG_LIST"
            ;;
        "SEARCH")
            local s=$(dialog --inputbox "Search Package Name:" 8 40 3>&1 1>&2 2>&3)
            grep -i "$s" "$TEMP_DIR/all_pkgs.txt" > "$PKG_LIST"
            ;;
        *)
            cat "$TEMP_DIR/all_pkgs.txt" > "$PKG_LIST"
            ;;
    esac
}

while true; do
    HEIGHT=$(tput lines); WIDTH=$(tput cols)
    
    # Pre-cache all packages for speed
    if [ -f /etc/redhat-release ]; then rpm -qa --queryformat '%{NAME} [Installed]\n' | sort > "$TEMP_DIR/all_pkgs.txt"
    else dpkg-query -W -f='${Package} [Installed]\n' | sort > "$TEMP_DIR/all_pkgs.txt"; fi

    # Category Selection
    CAT=$(dialog --clear --backtitle "Package Manager v1.1" --title "KATEGORI SECIMI" \
        --menu "Select a category to filter packages:" 15 65 6 \
        "SEARCH"   "Quick Search (By Name)" \
        "SERVICES" "Services & Daemons (Docker, SSH, Nginx...)" \
        "SECURITY" "Security & Audit Tools" \
        "SYSTEM"   "Core System Packages (Kernel, Libs...)" \
        "ALL"      "List All Packages (WARNING: Very Long)" \
        "X"        "UNINSTALL TOOLS & EXIT" 2>&1 >/dev/tty)

    [ -z "$CAT" ] && { rm -rf "$TEMP_DIR"; clear; break; }
    if [ "$CAT" == "X" ]; then 
        [ -f /etc/redhat-release ] && sudo dnf remove -y dialog || sudo apt-get remove -y dialog
        rm -rf "$TEMP_DIR"; clear; break;
    fi

    # Apply Filter
    get_filtered_list "$CAT"
    
    MENU_ITEMS=()
    while read -r name status; do
        MENU_ITEMS+=("$name" "$status")
    done < "$PKG_LIST"
    
    SELECTED_PKG=$(dialog --clear --title "$CAT Results" \
        --menu "Select a package to manage:" $HEIGHT $WIDTH $((HEIGHT - 10)) \
        "${MENU_ITEMS[@]}" "B" "<< BACK TO CATEGORIES" 2>&1 >/dev/tty)

    [ -z "$SELECTED_PKG" ] || [ "$SELECTED_PKG" == "B" ] && continue

    # Action Menu
    ACTION=$(dialog --clear --title "Manage: $SELECTED_PKG" \
        --menu "Action:" 15 60 4 \
        "1" "Info & Dependencies" \
        "2" "UNINSTALL (Safe)" \
        "3" "LOCK (No Updates)" \
        "4" "UNLOCK" 2>&1 >/dev/tty)

    case $ACTION in
        1) 
            [ -f /etc/redhat-release ] && rpm -qi "$SELECTED_PKG" > "$INFO_OUT" || apt-cache show "$SELECTED_PKG" > "$INFO_OUT"
            dialog --title "Package Info" --textbox "$INFO_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
            ;;
        2) 
            dialog --yesno "Uninstall $SELECTED_PKG?" 8 40
            if [ $? -eq 0 ]; then
                [ -f /etc/redhat-release ] && sudo dnf remove -y "$SELECTED_PKG" > "$INFO_OUT" || sudo apt-get purge -y "$SELECTED_PKG" > "$INFO_OUT"
                dialog --textbox "$INFO_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
            fi
            ;;
        3)
            if [ -f /etc/redhat-release ]; then sudo dnf versionlock add "$SELECTED_PKG"
            else echo "$SELECTED_PKG hold" | sudo dpkg --set-selections; fi
            dialog --msgbox "Locked!" 6 20
            ;;
    esac
done
