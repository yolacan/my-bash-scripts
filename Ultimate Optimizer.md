# Sistemi Swap kullanmaya zorlama, RAM'i sonuna kadar efektif kullan (%10 seviyesi idealdir)
vm.swappiness = 10

# Kirli (dirty) sayfaların RAM'den diske yazılma limitlerini optimize et
# Bu sayede disk I/O (özellikle yavaş SSD/HDD olan VPS'lerde) kilitlenmeleri önlenir
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10

# Sistem genelinde açılabilecek maksimum dosya (file descriptor) sınırını artır
# "Too many open files" hatasını engeller, yüksek trafikli servisler için şarttır
fs.file-max = 2097152

# TCP bağlantı kabul kuyruğunun maksimum sınırını artır (Varsayılan genelde 128 veya 512'dir)
net.core.somaxconn = 4096

# Ağ kartının işlem kuyruğunu (backlog) genişlet, yüksek pps (packet per second) durumlarında paket kaybını önler
net.core.netdev_max_backlog = 10000

# Bağlantı açma/kapama esnasındaki yarı açık (SYN) bağlantıların kuyruk sınırını artır
net.ipv4.tcp_max_syn_backlog = 4096

# Kapanış aşamasındaki (TIME_WAIT) bağlantıların zaman aşımı süresini düşür (Varsayılan 60 saniyedir)
# Böylece boşta bekleyen bağlantılar portları ve RAM'i gereksiz işgal etmez
net.ipv4.tcp_fin_timeout = 15

# Kapanmış ve TIME_WAIT durumundaki soketlerin yeni bağlantılar için hızlıca yeniden kullanılmasını sağla
net.ipv4.tcp_tw_reuse = 1

# TCP Okuma (Read) Buffer boyutları (min, default, max byte cinsinden)
net.ipv4.tcp_rmem = 4096 87380 16777216

# TCP Yazma (Write) Buffer boyutları (min, default, max byte cinsinden)
net.ipv4.tcp_wmem = 4096 65536 16777216

# Maksimum pencere boyutunu (window size) etkinleştir
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# SYN Flood saldırılarına karşı korumayı aktif et
net.ipv4.tcp_syncookies = 1

# RFC 1323 standardındaki TCP zaman damgalarını kapatarak CPU yükünü azalt (Opsiyoneldir ama LET'te çok önerilir)
net.ipv4.tcp_timestamps = 0

# ICMP (Ping) flood saldırılarına karşı yönlendirmeleri kapat
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
