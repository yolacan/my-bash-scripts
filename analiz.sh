#!/bin/bash

# İşletim sistemi tespiti
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s)
fi

# Geçici bir dosyaya çıktıları biriktirelim (Opsiyonel kayıt için)
TEMP_LOG=$(mktemp)

# Çıktı fonksiyonu (Hem ekrana basar hem dosyaya yazar)
log_output() {
    echo -e "$1" | tee -a "$TEMP_LOG"
}

log_output "--- Sistem Analizi Başlatılıyor ($OS) ---"

# Paket kontrol ve kurulum fonksiyonu
install_packages() {
    case $OS in
        ubuntu|debian|pop|mint)
            sudo apt-get update -y && sudo apt-get install -y sysstat procps
            ;;
        rhel|centos|fedora|almalinux|rocky)
            sudo dnf install -y sysstat procps-ng || sudo yum install -y sysstat procps-ng
            ;;
        *)
            echo "Desteklenmeyen işletim sistemi."
            ;;
    esac
}

if ! command -v sar &> /dev/null; then
    log_output "Gerekli araçlar (sysstat) bulunamadı. Kuruluyor..."
    install_packages
fi

log_output "========================================"
log_output "1. UPTIME (Sistem Yükü)\n$(uptime)"

log_output "\n2. DMESG (Son 10 Sistem Mesajı)\n$(dmesg | tail -n 10)"

log_output "\n3. VMSTAT (Bellek ve CPU Özeti)\n$(vmstat -S M 1 2)"

log_output "\n4. MPSTAT (CPU Başına Kullanım)\n$(mpstat -P ALL 1 1)"

log_output "\n5. IOSTAT (Disk Kullanımı - Human Readable)\n$(iostat -h -xz 1 1)"

log_output "\n6. FREE (Bellek Durumu - Human Readable)\n$(free -h)"

log_output "\n7. SAR - NETWORK (Ağ Trafiği)\n$(sar -n DEV 1 1)"

log_output "\n8. SAR - TCP (TCP İstatistikleri)\n$(sar -n TCP,ETCP 1 1)"

log_output "\n9. TOP (Süreç Özeti)\n$(top -b -n 1 | head -n 20)"

log_output "\n10. PIDSTAT (Süreç Detayları)\n$(pidstat 1 1)"
log_output "========================================"

# Kayıt Sorgusu
echo -n "Bu analizi bir .txt dosyasına kaydetmek ister misiniz? (e/h): "
read cevap

if [[ "$cevap" == "e" || "$cevap" == "E" ]]; then
    ZAMAN=$(date "+%Y-%m-%d_%H-%M")
    DOSYA_ADI="analiz_$ZAMAN.txt"
    
    # Zaman damgasını dosyanın en başına ekleyerek nihai dosyayı oluştur
    echo "Rapor Tarihi: $(date)" > "$DOSYA_ADI"
    cat "$TEMP_LOG" >> "$DOSYA_ADI"
    
    echo -e "\n[TAMAM] Rapor başarıyla kaydedildi: $DOSYA_ADI"
else
    echo -e "\nKayıt yapılmadan çıkılıyor."
fi

# Geçici dosyayı temizle
rm "$TEMP_LOG"
