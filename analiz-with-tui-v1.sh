#!/bin/bash

# İşletim sistemi tespiti ve paket kurulumu
install_deps() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    fi

    case $OS in
        ubuntu|debian|pop|mint)
            sudo apt-get update -y && sudo apt-get install -y sysstat procps whiptail
            ;;
        rhel|centos|fedora|almalinux|rocky)
            sudo dnf install -y sysstat procps-ng newt || sudo yum install -y sysstat procps-ng newt
            ;;
    esac
}

# Gerekli araçlar yoksa kur
if ! command -v whiptail &> /dev/null || ! command -v sar &> /dev/null; then
    install_deps
fi

# Geçici rapor dosyası
REPORT_FILE="sistem_analiz_raporu.txt"
echo "Sistem Analiz Raporu - $(date)" > "$REPORT_FILE"
echo "-----------------------------------" >> "$REPORT_FILE"

while true; do
    CHOICE=$(whiptail --title "Linux Sistem Analiz Paneli" --menu "Bir analiz komutu seçin (Gezinmek için ok tuşlarını kullanın):" 20 70 12 \
        "1" "UPTIME (Sistem Yükü)" \
        "2" "DMESG (Sistem Hataları)" \
        "3" "VMSTAT (Bellek/CPU Özeti)" \
        "4" "MPSTAT (CPU Başına Kullanım)" \
        "5" "IOSTAT (Disk Performansı)" \
        "6" "FREE (Ram Durumu - Human)" \
        "7" "SAR-NET (Ağ Trafiği)" \
        "8" "SAR-TCP (TCP Bağlantıları)" \
        "9" "TOP (Süreç Özeti)" \
        "10" "PIDSTAT (Süreç Detayları)" \
        "11" "RAPORU KAYDET VE ÇIK" \
        "12" "KAYDETMEDEN ÇIK" 3>&1 1>&2 2>&3)

    if [ -z "$CHOICE" ]; then break; fi

    case $CHOICE in
        1) CMD="uptime" ;;
        2) CMD="dmesg | tail -n 15" ;;
        3) CMD="vmstat -S M 1 2" ;;
        4) CMD="mpstat -P ALL 1 1" ;;
        5) CMD="iostat -h -xz 1 1" ;;
        6) CMD="free -h" ;;
        7) CMD="sar -n DEV 1 1" ;;
        8) CMD="sar -n TCP,ETCP 1 1" ;;
        9) CMD="top -b -n 1 | head -n 20" ;;
        10) CMD="pidstat 1 1" ;;
        11) 
            ZAMAN=$(date "+%Y%m%d_%H%M")
            mv "$REPORT_FILE" "analiz_$ZAMAN.txt"
            whiptail --msgbox "Rapor kaydedildi: analiz_$ZAMAN.txt" 8 45
            exit 0
            ;;
        12) 
            rm "$REPORT_FILE"
            exit 0
            ;;
    esac

    # Komutu çalıştır, hem rapora ekle hem ekranda göster
    OUTPUT=$(eval $CMD)
    echo -e "\n--- $CMD ---\n$OUTPUT" >> "$REPORT_FILE"
    
    # Sonucu whiptail ile göster
    whiptail --title "Komut Çıktısı: $CMD" --scrolltext --msgbox "$OUTPUT" 20 80
done
