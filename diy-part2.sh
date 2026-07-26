#!/bin/sh
# =====================================================================
# LiBwrt / 亚瑟 AX1800Pro 第一性原理【原子固化】终极重构脚本
# 严守目标：1级主路由 / 极致隐匿防DPI / 永固闪存矩阵 / 纯净底座
# =====================================================================

logger -t "DIY-Builder" "正在执行 LiBwrt 定制化底层重构与安全减法..."

# ---------------------------------------------------------------------
# 1. 改变网关防冲突：从底层源码硬编码隐匿 IP 坐标 (避开 192.168.1.1)
# ---------------------------------------------------------------------
echo ">> [1/4] 正在修改固件默认 IP 为 10.18.0.1..."
sed -i 's/192.168.1.1/10.18.0.1/g' package/base-files/files/bin/config_generate

# ---------------------------------------------------------------------
# 2. 编译期源头减法：彻底物理斩杀 SmartDNS、UPnP 与 ECM 硬件快通道
# ---------------------------------------------------------------------
echo ">> [2/4] 正在从构建链中剔除冗余应用与 DPI 漏流隐患模块..."
# 禁用冗余应用编译
sed -i '/smartdns/d' .config 2>/dev/null || true
sed -i '/luci-app-smartdns/d' .config 2>/dev/null || true
sed -i '/miniupnpd/d' .config 2>/dev/null || true
sed -i '/luci-app-upnp/d' .config 2>/dev/null || true

# 彻底刨除高通硬件连接管理器（保障 100% 流量进入 CPU 主内存接受 Netfilter/nftables 深度审计）
sed -i '/qca-nss-ecm/d' .config 2>/dev/null || true
sed -i '/kmod-qca-nss-ecm/d' .config 2>/dev/null || true

# ---------------------------------------------------------------------
# 3. 底层防线硬编码：固化底带 DMA 通道，强制烙印内核启动参数
# ---------------------------------------------------------------------
echo ">> [3/4] 正在预置反 DPI 底带配置与 eMMC 强制引导参数..."
mkdir -p package/base-files/files/etc/modprobe.d/
cat << 'EOF' > package/base-files/files/etc/modprobe.d/10-ath11k-nss.conf
# 开启 DMA 环形缓冲，保障 Wi-Fi 6 基础收发吞吐
options ath11k nss_offload=1
options ath11k_ahb nss_offload=1
# 绝对物理黑名单：死死封杀 ecm 加速模块！
blacklist qca_nss_ecm
EOF

# 强行向 qualcommax 底层内核模板烙印 eMMC 黄金坐标与 FORCE 参数 (终结 Cannot open root device 死锁)
find target/linux/qualcommax -name "config-*" | while read cfg; do
    sed -i '/CONFIG_CMDLINE/d' "$cfg"
    echo 'CONFIG_CMDLINE="console=ttyMSM0,115200n8 root=/dev/mmcblk0p18 rootwait rootfstype=squashfs,ext4"' >> "$cfg"
    echo 'CONFIG_CMDLINE_FORCE=y' >> "$cfg"
done

# ---------------------------------------------------------------------
# 4. 首次自举引擎：开机自动建区、构建安全网络蓝图与 Wi-Fi 6 大阵
# ---------------------------------------------------------------------
echo ">> [4/4] 正在构建首次开机物理自举引擎 (512M+300M+2G 存储矩阵 + 反 DPI 闭环)..."
mkdir -p package/base-files/files/etc/uci-defaults/
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
#!/bin/sh
# 该脚本仅在刷机后首次冷启动执行，闭环后自动销毁

logger -t "Stealth-Init" "系统首次初始化：正在构建防 DPI 策略与存储矩阵..."

# === [阶段 A：死锁反 DPI 防火墙与网关隐匿] ===
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

uci set network.lan.ipaddr='10.18.0.1'
uci set network.lan.netmash='255.255.255.0'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit network
uci commit dhcp

/bin/board_detect > /etc/board.json 2>/dev/null
rm -f /etc/config/wireless
wifi config > /etc/config/wireless

sed -i "s/option disabled '1'/option disabled '0'/g" /etc/config/wireless 2>/dev/null
uci -q set wireless.@wifi-device[0].country='CN' || uci -q set wireless.radio0.country='CN'
uci -q set wireless.@wifi-iface[0].ssid='Stealth-Core-5G' || uci -q set wireless.default_radio0.ssid='Stealth-Core-5G'
uci -q set wireless.@wifi-iface[0].encryption='psk2+ccmp' || uci -q set wireless.default_radio0.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[0].key='StealthRouter2026' || uci -q set wireless.default_radio0.key='StealthRouter2026'

uci -q set wireless.@wifi-device[1].country='CN' || uci -q set wireless.radio1.country='CN'
uci -q set wireless.@wifi-iface[1].ssid='Stealth-Core-2.4G' || uci -q set wireless.default_radio1.ssid='Stealth-Core-2.4G'
uci -q set wireless.@wifi-iface[1].encryption='psk2+ccmp' || uci -q set wireless.default_radio1.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[1].key='StealthRouter2026' || uci -q set wireless.default_radio1.key='StealthRouter2026'
uci commit wireless

# === [阶段 C：接驳 512M + 300M + 2G 硬盘矩阵，抛弃 17.4M 临时层] ===
if [ ! -f "/etc/config/storage_matrix_done" ]; then
    logger -t "Storage-Init" "正在将底层可写层映射至 eMMC 硬盘矩阵..."
    
    # 静默格式化目标硬盘分区
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
        
        # 将新 fstab 备份入原厂 p22 分区作为双重跳板
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
        logger -t "Stealth-Init" "物理自举与存储重构竣工！3秒后冷重启实现完全体合体！"
        reboot -f
    fi
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
