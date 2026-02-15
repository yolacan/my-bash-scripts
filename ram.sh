#!/bin/bash

# Force standard locale
export LC_ALL=C
export LANG=C

# Required Packages
PACKAGES="dialog util-linux procps-ng awk"

install_deps() {
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog util-linux procps
    fi
}

! command -v dialog &> /dev/null && install_deps

TEMP_DIR="/tmp/ram_expert"
mkdir -p $TEMP_DIR
TEMP_OUT="$TEMP_DIR/output.txt"

# --- Analiz Fonksiyonları ---

show_ram_breakdown() {
    {
        echo "--- OS LEVEL RAM VIEW (Standard) ---"
        free -h --total
        echo -e "\n--- EXPERT RAM VIEW (Why it looks full?) ---"
        # /proc/meminfo'dan verileri çekip insan diline çeviriyoruz
        cat /proc/meminfo | awk '
        /MemTotal/ {t=$2} /MemFree/ {f=$2} /MemAvailable/ {a=$2} /Cached/ {c=$2} /Active:/ {ac=$2} /Dirty/ {d=$2}
        END {
            printf "Total Physical RAM  : %.2f GB\n", t/1024/1024
            printf "Available for Apps   : %.2f GB (The REAL free amount)\n", a/1024/1024
            printf "Trapped in Cache     : %.2f GB (Used for disk speed)\n", c/1024/1024
            printf "Actual Free (Waste)  : %.2f GB (Unused RAM)\n", f/1024/1024
            printf "Dirty Memory         : %.2f MB (Waiting to be written to disk)\n", d/1024
        }'
        echo -e "\n--- SYSTEM ADVICE ---"
        echo "If 'Available' is high but 'Free' is low: DO NOT ADD RAM."
        echo "The system is just using idle RAM to speed up Database I/O."
    } > "$TEMP_OUT"
}

show_db_impact() {
    {
        echo "--- DATABASE SERVICE RAM USAGE ---"
        printf "%-20s %-10s %-10s %-10s\n" "PROCESS" "PID" "MEM %" "RSS (RAM)"
        # Oracle, MySQL, Postgres, MSSQL ve Docker'ı tarar
        ps aux | grep -Ei "oracle|mysql|postgres|sqlservr|docker|containerd" | grep -v grep | \
        awk '{printf "%-20s %-10s %-10s %-10s\n", $11, $2, $4"%", $6/1024"MB"}' | sort -k4 -rn
        
        echo -e "\n--- DATABASE TUNING HINT ---"
        echo "Check your SGA/PGA (Oracle) or Innodb_buffer_pool (MySQL)."
        echo "If the DB process uses less than 80% of 'Available' RAM, you are safe."
    } > "$TEMP_OUT"
}

# --- Dashboard Döngüsü ---
while true; do
    HEIGHT=$(tput lines); WIDTH=$(tput cols)
    [ $HEIGHT -lt 20 ] && HEIGHT=20
    [ $WIDTH -lt 75 ] && WIDTH=75

    CHOICE=$(dialog --clear --backtitle "DBA vs Admin Peacemaker" --title "RAM & DATABASE ANALYZER" \
        --menu "Select Analysis Mode:" $HEIGHT $WIDTH $((HEIGHT - 12)) \
        "1" "OS RAM Analysis (Detailed Breakdown)" \
        "2" "DB Processes (Active Memory Usage)" \
        "3" "Memory Pressure (Check for Swapping)" \
        "X" "UNINSTALL TOOLS & EXIT" "Q" "EXIT" 2>&1 >/dev/tty)

    [ -z "$CHOICE" ] || [ "$CHOICE" == "Q" ] && break
    if [ "$CHOICE" == "X" ]; then 
        [ -f /etc/redhat-release ] && sudo dnf remove -y $PACKAGES || sudo apt-get remove -y $PACKAGES
        break 
    fi

    case $CHOICE in
        1) show_ram_breakdown ;;
        2) show_db_impact ;;
        3) vmstat 1 5 > "$TEMP_OUT" ;;
    esac

    dialog --title "Analysis Result" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
done
rm -rf "$TEMP_DIR"
