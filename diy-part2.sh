#!/bin/sh
# =====================================================================
# 亚瑟 AX1800Pro 第一性原理【编译期原子固化】终极源码重构脚本
# 严守目标：1级主路由 / 极致隐匿防DPI / 永固闪存矩阵 / 零维护开机自举
# =====================================================================

# ---------------------------------------------------------------------
# 1. 改变网关防冲突：从底层源码硬编码隐匿 IP 坐标 (避开 192.168.1.1)
# ---------------------------------------------------------------------
echo ">> [1/5] 正在修改固件默认 IP 为 10.18.0.1..."
sed -i 's/192.168.1.1/10.18.0.1/g' package/base-files/files/bin/config_generate

# ---------------------------------------------------------------------
# 2. 射频真理注入：拉取京东云专属 BDF 固件包，对齐 board_id 0xff 兜底
# ---------------------------------------------------------------------
echo ">> [2/5] 正在获取 jdcloud_re-ss-01 专属射频真理表 board-2.bin..."
mkdir -p package/firmware/ipq-wifi/files/lib/firmware/ath11k/IPQ6018/hw1.0/
curl -sL https://raw.githubusercontent.com/qca/qca-wireless-firmware/master/IPQ6018/board-2.bin \
    -o package/firmware/ipq-wifi/files/lib/firmware/ath11k/IPQ6018/hw1.0/board-2.bin || true

# ---------------------------------------------------------------------
# 3. 硬件校准抽取：植入 eMMC 4KB 脏填充头自动剥离热插拔脚本 (防止 -22)
# ---------------------------------------------------------------------
echo ">> [3/5] 正在植入 eMMC p15 (0:ART) 硬件频偏校准热插拔脚本..."
mkdir -p package/base-files/files/etc/hotplug.d/firmware/
cat << 'EOF' > package/base-files/files/etc/hotplug.d/firmware/11-ath11k-caldata
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
case "$FIRMWARE" in
    *cal-ahb-c000000.wifi.bin*)
        # 物理层寻址：定位全 eMMC 架构的 0:ART 闪存块设备
        ART_PART=$(ls -1 /dev/mmcblk0p* 2>/dev/null | while read part; do [ "$(block info $part | grep -c 'ART')" -gt 0 ] && echo $part && break; done)
        [ -z "$ART_PART" ] && ART_PART="/dev/mmcblk0p15"
        if [ -b "$ART_PART" ]; then
            # 第一性原理：精准跳过 LBA 前 4KB 扇区对齐头，提取 128KB 纯净校准矩阵
            dd if=$ART_PART of=/lib/firmware/$FIRMWARE bs=4096 skip=1 count=32 2>/dev/null
            chmod 644 /lib/firmware/$FIRMWARE
        fi
        ;;
esac
EOF
chmod +x package/base-files/files/etc/hotplug.d/firmware/11-ath11k-caldata

# ---------------------------------------------------------------------
# 4. 反 DPI 绝密隐匿：固化底带 DMA 通道，从根源锁死 ECM 快通道
# ---------------------------------------------------------------------
echo ">> [4/5] 正在预置底带驱动参数，确保零漏流隐匿监控..."
mkdir -p package/base-files/files/etc/modprobe.d/
cat << 'EOF' > package/base-files/files/etc/modprobe.d/10-ath11k-nss.conf
# 开启 DMA 环形缓冲，保障 Wi-Fi 6 基础收发吞吐
options ath11k nss_offload=1
options ath11k_ahb nss_offload=1
# 物理黑名单：绝对禁止加载 ecm 连接管理器，防止网络流量绕过 Netfilter 防火墙！
blacklist qca_nss_ecm
EOF

# 修改内核网络模块，默认开启 Wi-Fi 芯片注册
sed -i 's/disabled=1/disabled=0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh 2>/dev/null || true

# ---------------------------------------------------------------------
# 5. 首次自举引擎：开机自动建区、生成网络/无线蓝图并死锁防火墙
# ---------------------------------------------------------------------
echo ">> [5/5] 正在构建开机首次自举引擎 (存储矩阵 + 网络架构 + Wi-Fi大阵)..."
mkdir -p package/base-files/files/etc/uci-defaults/
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
#!/bin/sh
# 该自举脚本仅在固件刷入后第一次开机运行，执行后系统会自动将其销毁

logger -t "Stealth-Init" "正在执行系统的首次物理自举与安全闭环..."

# === [阶段 A：死锁反 DPI 防火墙与网关区间] ===
# 彻底关掉硬件/软件流量卸载，强迫 100% 流量升入 CPU 主内存接受 DPI 抓包审计！
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

# 强行固化 LAN 口 IP 为 10.18.0.1，并设置安全的 DHCP 隐匿区间
uci set network.lan.ipaddr='10.18.0.1'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit network
uci commit dhcp

# === [阶段 B：唤醒 Wi-Fi 6 双频大阵并硬编码加密规则] ===
/bin/board_detect > /etc/board.json 2>/dev/null
rm -f /etc/config/wireless
wifi config > /etc/config/wireless

# 解开所有可能的射频锁，强制通电释能
sed -i "s/option disabled '1'/option disabled '0'/g" /etc/config/wireless 2>/dev/null
sed -i "s/option disabled '0'/option disabled '0'/g" /etc/config/wireless 2>/dev/null

# 精准定位 5G 与 2.4G 物理底座，注入隐匿 SSID 与加密密码
uci -q set wireless.@wifi-device[0].country='CN' || uci -q set wireless.radio0.country='CN'
uci -q set wireless.@wifi-iface[0].ssid='Stealth-Core-5G' || uci -q set wireless.default_radio0.ssid='Stealth-Core-5G'
uci -q set wireless.@wifi-iface[0].encryption='psk2+ccmp' || uci -q set wireless.default_radio0.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[0].key='这里替换为你想要的WiFi密码' || uci -q set wireless.default_radio0.key='这里替换为你想要的WiFi密码'

uci -q set wireless.@wifi-device[1].country='CN' || uci -q set wireless.radio1.country='CN'
uci -q set wireless.@wifi-iface[1].ssid='Stealth-Core-2.4G' || uci -q set wireless.default_radio1.ssid='Stealth-Core-2.4G'
uci -q set wireless.@wifi-iface[1].encryption='psk2+ccmp' || uci -q set wireless.default_radio1.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[1].key='这里替换为你想要的WiFi密码' || uci -q set wireless.default_radio1.key='这里替换为你想要的WiFi密码'
uci commit wireless

# === [阶段 C：构建 512M + 300M + 2G 硬盘矩阵，砸碎临时内存盘陷阱] ===
if [ ! -f "/etc/config/storage_matrix_done" ]; then
    logger -t "Storage-Init" "正在重构底层物理硬盘矩阵..."
    
    # 静默格式化目标扇区
    mkfs.ext4 -F /dev/mmcblk0p26 2>/dev/null
    mkfs.ext4 -F /dev/mmcblk0p25 2>/dev/null
    PART_2G=$(ls -1 /dev/mmcblk0p* 2>/dev/null | grep -E "p27|p28" | head -n 1)
    [ -n "$PART_2G" ] && mkfs.ext4 -F $PART_2G 2>/dev/null
    
    UUID_P26=$(block info /dev/mmcblk0p26 2>/dev/null | awk -F"UUID=" '{print $2}' | cut -d'"' -f2)
    UUID_P25=$(block info /dev/mmcblk0p25 2>/dev/null | awk -F"UUID=" '{print $2}' | cut -d'"' -f2)
    UUID_P2G=$(block info $PART_2G 2>/dev/null | awk -F"UUID=" '{print $2}' | cut -d'"' -f2)
    
    if [ -n "$UUID_P26" ] && [ -n "$UUID_P25" ]; then
        cat << FSTAB > /etc/config/fstab
config global
        option anon_swap '0'
        option anon_mount '0'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/overlay'
        option uuid '$UUID_P26'
        option fstype 'ext4'
        option options 'rw,sync'
        option enabled '1'

config mount
        option target '/opt'
        option uuid '$UUID_P25'
        option fstype 'ext4'
        option options 'rw,sync'
        option enabled '1'
FSTAB
        if [ -n "$UUID_P2G" ]; then
            cat << FSTAB_2G >> /etc/config/fstab

config mount
        option target '/emmc_2G'
        option uuid '$UUID_P2G'
        option fstype 'ext4'
        option options 'rw,sync'
        option enabled '1'
FSTAB_2G
        fi
        
        # 将 FSTAB 双重跳板备份烙印入原厂 p22 分区
        mkdir -p /mnt/p22_tmp
        mount /dev/mmcblk0p22 /mnt/p22_tmp 2>/dev/null
        if [ $? -eq 0 ]; then
            mkdir -p /mnt/p22_tmp/upper/etc/config /mnt/p22_tmp/etc/config
            cp -f /etc/config/fstab /mnt/p22_tmp/upper/etc/config/fstab 2>/dev/null
            cp -f /etc/config/fstab /mnt/p22_tmp/etc/config/fstab 2>/dev/null
            sync && umount /mnt/p22_tmp
        fi
        
        touch /etc/config/storage_matrix_done
        sync
        logger -t "Stealth-Init" "物理自举完毕！3秒后执行冷重启动，进入彻底合体态！"
        reboot -f
    fi
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
