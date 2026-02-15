#!/bin/bash

# Standart Dil Ayarları (Global uyumluluk)
export LC_ALL=C
export LANG=C

# Bağımlılık Listesi
PACKAGES="dialog sysstat bc net-tools util-linux procps-ng"

# Kurulum Fonksiyonu
install_deps() {
    echo "Gerekli araçlar kontrol ediliyor..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog sysstat bc net-tools util-linux procps
    fi
}

# Temizlik Fonksiyonu (14. Madde için)
remove_deps() {
    clear
    echo "Sistem temizleniyor..."
    if [ -f /etc/redhat-release ]; then
        sudo dnf remove -y $PACKAGES
    elif [ -f /etc/debian_version ]; then
        sudo apt-get remove -y dialog sysstat bc net-tools util-linux procps
        sudo apt-get autoremove -y
    fi
    echo "Temizlik tamamlandı. Güle güle!"
    sleep 2
}

# Script başlar başlamaz kurulumu kontrol et
install_deps

REPORT_FILE="system_analysis_$(date +%Y%m%d_%H%M).txt"
TEMP_OUT="/tmp/analiz_v12.txt"
touch "$TEMP_OUT"

# --- Fonksiyonlar ---

health_check() {
    {
        echo "--- QUICK HEALTH CHECK ---"
        echo "Date: $(date)"
        echo "--------------------------"
        df -h / | awk 'NR==2 {print "[OK] Disk Usage: " $5}'
        uptime | awk -F'load average:' '{print "[OK] Load Average: " $2}'
        free | grep Mem | awk '{printf "[OK] Free RAM Ratio: %d%%\n", $4/$2 * 100}'
    } > "$TEMP_OUT"
}

active_services() {
    {
        echo "--- ACTIVE SERVICES ---"
        echo "-----------------------"
        systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print "[ACTIVE] " $1}'
    } > "$TEMP_OUT"
}

while true; do
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    MENU_H=$((HEIGHT - 8))

    CHOICE=$(dialog --clear --title "Linux Analyzer v12 (Auto-Install & Clean)" \
        --menu "Select a command:" $HEIGHT $WIDTH $MENU_H \
        "1" "UPTIME (System Load)" \
        "2" "DMESG (Kernel Logs)" \
        "3" "VMSTAT (Resource Summary)" \
        "4" "MPSTAT (CPU Breakdown)" \
        "5" "IOSTAT (Disk I/O)" \
        "6" "FREE (RAM Status)" \
        "7" "SAR-NET (Network Traffic)" \
        "8" "TOP (Process List)" \
        "9" "LISTEN (Open Ports)" \
        "10" "HEALTH-CHECK (Summary)" \
        "11" "ACTIVE-SERVICES (Running)" \
        "12" "SAVE REPORT" \
        "13" "EXIT" \
        "14" "UNINSTALL TOOLS & EXIT" 2>&1 >/dev/tty)

    [ $? -ne 0 ] || [ "$CHOICE" == "13" ] && break

    if [ "$CHOICE" == "14" ]; then
        remove_deps
        break
    fi

    case $CHOICE in
        1) uptime > "$TEMP_OUT" ;;
        2) dmesg | tail -n 25 > "$TEMP_OUT" ;;
        3) vmstat -S M 1 2 > "$TEMP_OUT" ;;
        4) mpstat -P ALL 1 1 > "$TEMP_OUT" ;;
        5) iostat -h -xz 1 1 > "$TEMP_OUT" ;;
        6) free -h -t > "$TEMP_OUT" ;;
        7) sar -n DEV 1 1 > "$TEMP_OUT" ;;
        8) top -b -n 1 | head -n 40 > "$TEMP_OUT" ;;
        9) ss -tulpn | column -t > "$TEMP_OUT" ;;
        10) health_check ;;
        11) active_services ;;
        12) dialog --msgbox "Report saved: $REPORT_FILE" 8 45 ;;
    esac

    # Raporlama ve Gösterim
    if [ "$CHOICE" != "12" ]; then
        echo -e "\n--- Choice $CHOICE ---\n$(cat "$TEMP_OUT")" >> "$REPORT_FILE"
        dialog --title "Result: Option $CHOICE" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
    fi
done

clear
rm -f "$TEMP_OUT"
