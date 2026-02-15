#!/bin/bash

# Force standard locale for global compatibility
export LC_ALL=C
export LANG=C

# Required Packages
PACKAGES="dialog util-linux grep sed awk"

# Dependency Check & Auto-Install
install_deps() {
    echo "Checking dependencies..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog util-linux grep sed awk
    fi
}

! command -v dialog &> /dev/null && install_deps

TEMP_DIR="/tmp/log_explorer"
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
            [ ! -s "$TEMP_OUT" ] && echo "No critical errors found in this log." > "$TEMP_OUT"
            ;;
        "3") # Statistics Mode
            local err=$(grep -ci "error" "$file")
            local crit=$(grep -ci "critical" "$file")
            local warn=$(grep -ci "warning" "$file")
            local fail=$(grep -ci "fail" "$file")
            {
                echo "LOG STATISTICS: $file"
                echo "--------------------------------------"
                echo "ERRORS    : $err"
                echo "CRITICAL  : $crit"
                echo "WARNINGS  : $warn"
                echo "FAILED    : $fail"
                echo "--------------------------------------"
                echo "Report Date: $(date)"
            } > "$TEMP_OUT"
            ;;
        "4") # Custom String Search
            local search=$(dialog --title "Custom Search" --inputbox "Enter string to search (case-insensitive):" 8 40 3>&1 1>&2 2>&3)
            [ -z "$search" ] && return
            grep -i "$search" "$file" | tail -n 100 > "$TEMP_OUT"
            [ ! -s "$TEMP_OUT" ] && echo "No matches found for: $search" > "$TEMP_OUT"
            ;;
    esac
}

# --- Main Loop ---
while true; do
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    
    # Scan for log files (Max depth 2 for performance)
    find /var/log -maxdepth 2 -type f \( -name "*.log" -o -name "messages" -o -name "syslog" -o -name "secure" -o -name "auth.log" \) 2>/dev/null > "$LOG_LIST"
    
    # Format files for Dialog Menu
    MENU_ITEMS=()
    i=1
    while read -r line; do
        MENU_ITEMS+=("$i" "$line")
        ((i++))
    done < "$LOG_LIST"
    
    SELECTED_INDEX=$(dialog --clear --title "Log Explorer & Analyzer v1.0" \
        --menu "Select a log file to investigate:" $HEIGHT $WIDTH $((HEIGHT - 10)) \
        "${MENU_ITEMS[@]}" "Q" "QUIT AND CLEANUP" 2>&1 >/dev/tty)

    [[ "$SELECTED_INDEX" == "Q" || -z "$SELECTED_INDEX" ]] && break

    # Get file path from list
    SELECTED_FILE=$(sed -n "${SELECTED_INDEX}p" "$LOG_LIST")

    # Action Menu
    ACTION=$(dialog --clear --title "File: $SELECTED_FILE" \
        --menu "Choose an action:" 15 60 6 \
        "1" "Read Last 100 Lines" \
        "2" "Filter Critical Errors" \
        "3" "Show Error Statistics (Count)" \
        "4" "Custom String Search" \
        "5" "Live Stream (Tail -f)" \
        "B" "Back to File List" 2>&1 >/dev/tty)

    [ "$ACTION" == "B" ] || [ -z "$ACTION" ] && continue

    if [ "$ACTION" == "5" ]; then
        clear
        echo -e "STREAMING LOG: $SELECTED_FILE"
        echo "Press CTRL+C to stop and return to menu..."
        sleep 2
        tail -f "$SELECTED_FILE"
        continue
    fi

    analyze_log "$SELECTED_FILE" "$ACTION"
    
    # Show Results in Textbox
    dialog --title "Log Content: $SELECTED_FILE" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
done

# Cleanup before exit
rm -rf "$TEMP_DIR"
clear
echo "Cleanup complete. Terminal restored."
