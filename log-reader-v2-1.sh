#!/bin/bash

# Force standard locale for global compatibility
export LC_ALL=C
export LANG=C

# Required Packages
PACKAGES="dialog util-linux grep sed awk"

# Dependency Check & Auto-Install
install_deps() {
    echo "Checking and installing dependencies..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog util-linux grep sed awk
    fi
}

# Uninstall Function
uninstall_all() {
    clear
    echo "Uninstalling tools and cleaning system..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf remove -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get remove -y dialog util-linux grep sed awk
        sudo apt-get autoremove -y
    fi
    rm -rf "$TEMP_DIR"
    echo "System is clean. Goodbye!"
    sleep 1
}

# Run install at start
install_deps

TEMP_DIR="/tmp/log_explorer_v2"
mkdir -p $TEMP_DIR
TEMP_OUT="$TEMP_DIR/output.txt"
LOG_LIST="$TEMP_DIR/logs.txt"

# --- Core Analysis Function ---
analyze_log() {
    local file=$1
    local mode=$2
    
    case $mode in
        "1") # Read last 100 lines
            tail -n 100 "$file" > "$TEMP_OUT"
            ;;
        "2") # Error Filter
            grep -Ei "error|critical|fail|severe|panic" "$file" | tail -n 100 > "$TEMP_OUT"
            [ ! -s "$TEMP_OUT" ] && echo "No critical errors found." > "$TEMP_OUT"
            ;;
        "3") # Statistics Mode
            local err=$(grep -ci "error" "$file")
            local crit=$(grep -ci "critical" "$file")
            local warn=$(grep -ci "warning" "$file")
            {
                echo "LOG STATISTICS: $file"
                echo "--------------------------------------"
                echo "ERRORS    : $err"
                echo "CRITICAL  : $crit"
                echo "WARNINGS  : $warn"
                echo "--------------------------------------"
            } > "$TEMP_OUT"
            ;;
        "4") # Custom Search with Guide
            dialog --title "Search Guide" --msgbox \
            "Search Tips:\n\n1. Use \"word\" for simple search.\n2. Example: \"error 404\" matches the phrase.\n3. Case-insensitive search is active." 10 50
            
            local search=$(dialog --title "Custom Search" --inputbox "Enter string to search:" 8 40 3>&1 1>&2 2>&3)
            [ -z "$search" ] && return
            grep -Ei "$search" "$file" | tail -n 100 > "$TEMP_OUT"
            [ ! -s "$TEMP_OUT" ] && echo "No matches found for: $search" > "$TEMP_OUT"
            ;;
    esac
}

# --- Main Loop ---
while true; do
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    
    # Scan for log files
    find /var/log -maxdepth 2 -type f \( -name "*.log" -o -name "messages" -o -name "syslog" -o -name "auth.log" -o -name "secure" \) 2>/dev/null > "$LOG_LIST"
    
    MENU_ITEMS=()
    i=1
    while read -r line; do
        MENU_ITEMS+=("$i" "$line")
        ((i++))
    done < "$LOG_LIST"
    
    SELECTED_INDEX=$(dialog --clear --backtitle "Log Analyzer v2.2" --title "Main Menu" \
        --menu "Select a log file or action:" $HEIGHT $WIDTH $((HEIGHT - 12)) \
        "P" "[ MANUALLY ENTER LOG PATH ]" \
        "${MENU_ITEMS[@]}" \
        "X" "[ UNINSTALL TOOLS & EXIT ]" \
        "Q" "[ JUST EXIT ]" 2>&1 >/dev/tty)

    # Exit scenarios
    [ -z "$SELECTED_INDEX" ] || [ "$SELECTED_INDEX" == "Q" ] && { rm -rf "$TEMP_DIR"; clear; break; }
    if [ "$SELECTED_INDEX" == "X" ]; then uninstall_all; break; fi

    # Determine file path
    if [ "$SELECTED_INDEX" == "P" ]; then
        SELECTED_FILE=$(dialog --title "Manual Path" --inputbox "Full path to log file:" 8 60 3>&1 1>&2 2>&3)
        [ ! -f "$SELECTED_FILE" ] && { dialog --msgbox "File not found!" 6 30; continue; }
    else
        SELECTED_FILE=$(sed -n "${SELECTED_INDEX}p" "$LOG_LIST")
    fi

    # Sub-Menu Action
    ACTION=$(dialog --clear --title "File: $SELECTED_FILE" \
        --menu "Action:" 15 60 6 \
        "1" "Read Last 100 Lines" \
        "2" "Filter Critical Errors" \
        "3" "Show Error Statistics" \
        "4" "Custom Search" \
        "5" "Live Stream (Tail -f)" \
        "B" "Back to Menu" 2>&1 >/dev/tty)

    [ -z "$ACTION" ] || [ "$ACTION" == "B" ] && continue

    if [ "$ACTION" == "5" ]; then
        clear
        echo "STREAMING: $SELECTED_FILE"
        echo "Press CTRL+C to stop..."
        sleep 1
        tail -f "$SELECTED_FILE"
        continue
    fi

    # Process and Show Result
    analyze_log "$SELECTED_FILE" "$ACTION"
    dialog --title "Result: $SELECTED_FILE" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
done

rm -rf "$TEMP_DIR"
