#!/bin/sh

logger -t "DIY-Builder" "Libwrt-pure"

sed -i 's/192.168.1.1/172.18.16.1/g' package/base-files/files/bin/config_generate

sed -i '/smartdns/d' .config 2>/dev/null || true
sed -i '/luci-app-smartdns/d' .config 2>/dev/null || true
sed -i '/miniupnpd/d' .config 2>/dev/null || true
sed -i '/luci-app-upnp/d' .config 2>/dev/null || true

sed -i '/qca-nss-ecm/d' .config 2>/dev/null || true
sed -i '/kmod-qca-nss-ecm/d' .config 2>/dev/null || true

mkdir -p package/base-files/files/etc/modprobe.d/
cat << 'EOF' > package/base-files/files/etc/modprobe.d/10-ath11k-nss.conf
options ath11k nss_offload=1
options ath11k_ahb nss_offload=1
blacklist qca_nss_ecm
EOF

mkdir -p package/base-files/files/etc/uci-defaults/
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
#!/bin/sh

logger -t "Stealth-Init" "WLAN"

uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

uci set network.lan.ipaddr='172.18.16.1'
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
uci -q set wireless.@wifi-iface[0].ssid='Home-5G' || uci -q set wireless.default_radio0.ssid='Home-5G'
uci -q set wireless.@wifi-iface[0].encryption='psk2+ccmp' || uci -q set wireless.default_radio0.encryption='psk2+ccmp'
# chang with the password you want
uci -q set wireless.@wifi-iface[0].key='123456' || uci -q set wireless.default_radio0.key='123456'

uci -q set wireless.@wifi-device[1].country='CN' || uci -q set wireless.radio1.country='CN'
uci -q set wireless.@wifi-iface[1].ssid='Home-2.4G' || uci -q set wireless.default_radio1.ssid='Home-2.4G'
uci -q set wireless.@wifi-iface[1].encryption='psk2+ccmp' || uci -q set wireless.default_radio1.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[1].key='123456' || uci -q set wireless.default_radio1.key='123456'
uci commit wireless

if [ ! -f "/etc/config/storage_matrix_done" ]; then
    logger -t "Storage-Init" "Mermory
    
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
        logger -t "Stealth-Init" "Reboot"
        reboot -f
    fi
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
echo "CONFIG_KERNEL_SKB_EXTENSIONS=y" >> .config
echo "CONFIG_KERNEL_NET_TC_SKB_EXT=y" >> .config
echo "CONFIG_KERNEL_NET_RX_BUSY_POLL=y" >> .config
logger -t "Kernel-Fix" "Fix finish!"
