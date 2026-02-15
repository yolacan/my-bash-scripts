#!/bin/bash

# Dil ayarlarını standart yapalım
export LC_ALL=C
export LANG=C

# Bağımlılık kontrolü (dialog ve diğerleri)
install_deps() {
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y dialog sysstat bc net-tools
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update -qq && sudo apt-get install -y dialog sysstat bc net-tools
    fi
}

# dialog yoksa kur
! command -v dialog &> /dev/null && install_deps

REPORT_FILE="system_analysis_$(date +%Y%m%d_%H%M).txt"
TEMP_OUT="/tmp/analiz_v11.txt"
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
    # Ekran boyutlarını al
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    MENU_H=$((HEIGHT - 8))

    # CHOICE değişkenine dialog sonucunu ata
    CHOICE=$(dialog --clear --title "Linux Analyzer v11 (Ultra Stable)" \
        --menu "Select a command (Use arrows and Enter):" $HEIGHT $WIDTH $MENU_H \
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
        "12" "SAVE & EXIT" \
        "13" "EXIT WITHOUT SAVING" 2>&1 >/dev/tty)

    # Çıkış kontrolü
    [ $? -ne 0 ] || [ "$CHOICE" == "13" ] && break

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
        12) dialog --msgbox "Report saved: $REPORT_FILE" 8 45; break ;;
    esac

    # Rapor dosyasına kaydet
    echo -e "\n--- Choice $CHOICE ---\n$(cat "$TEMP_OUT")" >> "$REPORT_FILE"

    # SONUÇ EKRANI: Dosyadan doğrudan okuduğu için karakter hatası yapmaz
    dialog --title "Result: Option $CHOICE" --textbox "$TEMP_OUT" $((HEIGHT - 4)) $((WIDTH - 4))
done

clear
rm -f "$TEMP_OUT"
