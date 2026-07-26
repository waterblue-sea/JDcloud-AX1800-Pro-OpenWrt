#!/bin/sh
sed -i 's/192.168.1.1/10.18.0.1/g' package/base-files/files/bin/config_generate    

sed -i 's/3.31/3.25/g' feeds/luci/libs/rpcd-mod-luci/CMakeLists.txt 2>/dev/null || true

sed -i -E '/kmod-qca-nss-drv-(pppoe|pptp|l2tpv2|pvxlanmgr|tun6rd|tunipip6|gre|map-t|ecm)/d' .config
sed -i -E '/kmod-(pptp|l2tp|gre)/d' .config
echo '# CONFIG_PACKAGE_kmod-qca-nss-ecm is not set' >> .config
echo '# CONFIG_PACKAGE_qca-nss-ecm is not set' >> .config

find target/linux/qualcommax/ -name "*.mk" -o -name "Makefile" | xargs sed -i -E 's/kmod-qca-nss-drv-(pppoe|pptp|l2tpv2|pvxlanmgr|tun6rd|tunipip6|gre|map-t|ecm)//g'
find target/linux/qualcommax/ -name "*.mk" -o -name "Makefile" | xargs sed -i -E 's/kmod-(pptp|l2tp|gre)//g'

find target/linux/qualcommax -name "config-*" | while read cfg; do
    sed -i '/CONFIG_NF_CONNTRACK_DSCPREMARK_EXT/d' "$cfg"
    echo '# CONFIG_NF_CONNTRACK_DSCPREMARK_EXT is not set' >> "$cfg"
    
    sed -i '/CONFIG_CMDLINE/d' "$cfg"
    echo 'CONFIG_CMDLINE="console=ttyMSM0,115200n8"' >> "$cfg"
    echo 'CONFIG_CMDLINE_EXTEND=y' >> "$cfg"
done

mkdir -p package/base-files/files/etc/modprobe.d/
cat << 'EOF' > package/base-files/files/etc/modprobe.d/10-ath11k-nss.conf
options ath11k nss_offload=1
options ath11k_ahb nss_offload=1
blacklist qca_nss_ecm
EOF

mkdir -p package/base-files/files/etc/uci-defaults/
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
#!/bin/sh

uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

uci set network.lan.ipaddr='10.18.0.1'
uci set network.lan.netmask='255.255.255.0'
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
uci -q set wireless.@wifi-iface[0].key='StealthRouter2026' || uci -q set wireless.default_radio0.key='StealthRouter2026'

uci -q set wireless.@wifi-device[1].country='CN' || uci -q set wireless.radio1.country='CN'
uci -q set wireless.@wifi-iface[1].ssid='Home-2.4G' || uci -q set wireless.default_radio1.ssid='Home-2.4G'
uci -q set wireless.@wifi-iface[1].encryption='psk2+ccmp' || uci -q set wireless.default_radio1.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[1].key='StealthRouter2026' || uci -q set wireless.default_radio1.key='StealthRouter2026'
uci commit wireless

if [ ! -f "/etc/config/storage_matrix_done" ]; then

    logger -t "Storage-Init" "eMMC"

    if ! blkid /dev/mmcblk0p26 | grep -q "ext4"; then
        mkfs.ext4 -F -O ^has_journal /dev/mmcblk0p26 2>/dev/null
    fi
    if ! blkid /dev/mmcblk0p25 | grep -q "ext4"; then
        mkfs.ext4 -F /dev/mmcblk0p25 2>/dev/null
    fi
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
        logger -t "Stealth-Init" "Finish!"
        (sleep 5 && reboot) &
    fi
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
