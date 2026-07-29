#!/bin/sh

sed -i 's/192.168.1.1/172.18.16.1/g' package/base-files/files/bin/config_generate    

find feeds/ -type f -name "CMakeLists.txt" -exec sed -i 's/3.31/3.25/g' {} +

for app in argon-config diskman openclash smartdns uhttpd unblockneteasemusic upnp passwall; do
    sed -i "/CONFIG_PACKAGE_luci-app-${app}=y/d" .config
    echo "# CONFIG_PACKAGE_luci-app-${app} is not set" >> .config
done

for useless_pkg in ZABBIX_POSTGRESQL PACKAGE_node NODEJS_ PACKAGE_ruby PACKAGE_iperf PACKAGE_iperf3 PACKAGE_6in4 PACKAGE_6rd PACKAGE_miniupnpd; do
    sed -i "/CONFIG_${useless_pkg}/d" .config
done

for proxy_core in passwall xray sing-box trojan-plus shadowsocks-rust; do
    sed -i "/${proxy_core}/d" .config
done

sed -i '/CONFIG_LIBCURL_NGHTTP3/d' .config
sed -i '/CONFIG_LIBCURL_NGTCP2/d' .config
sed -i '/CONFIG_PACKAGE_libnghttp3/d' .config
sed -i '/CONFIG_PACKAGE_libngtcp2/d' .config
sed -i '/CONFIG_OVERRIDE_PKGS/d' .config

echo '# CONFIG_LIBCURL_NGHTTP3 is not set' >> .config
echo '# CONFIG_LIBCURL_NGTCP2 is not set' >> .config
echo '# CONFIG_PACKAGE_libnghttp3 is not set' >> .config
echo '# CONFIG_PACKAGE_libngtcp2 is not set' >> .config

cat << 'EOF' >> .config
# CONFIG_ZABBIX_POSTGRESQL is not set
# CONFIG_PACKAGE_node is not set
# CONFIG_PACKAGE_ruby is not set
# CONFIG_PACKAGE_iperf is not set
# CONFIG_PACKAGE_iperf3 is not set
# CONFIG_PACKAGE_6in4 is not set
# CONFIG_PACKAGE_6rd is not set
# CONFIG_PACKAGE_miniupnpd is not set
# CONFIG_PACKAGE_miniupnpd-nftables is not set
EOF

sed -i -E '/kmod-qca-nss-drv-(pppoe|pptp|l2tpv2|pvxlanmgr|tun6rd|tunipip6|gre|map-t)/d' .config
sed -i -E '/kmod-(pptp|l2tp|gre)/d' .config
sed -i -E '/kmod-qca-nss-ecm/d' .config
sed -i -E '/qca-nss-ecm/d' .config
echo '# CONFIG_PACKAGE_kmod-qca-nss-ecm is not set' >> .config
echo '# CONFIG_PACKAGE_qca-nss-ecm is not set' >> .config

find target/linux/qualcommax/ -name "*.mk" -o -name "Makefile" | xargs sed -i -E 's/kmod-qca-nss-drv-(pppoe|pptp|l2tpv2|pvxlanmgr|tun6rd|tunipip6|gre|map-t)//g'
find target/linux/qualcommax/ -name "*.mk" -o -name "Makefile" | xargs sed -i -E 's/kmod-(pptp|l2tp|gre)//g'
find target/linux/qualcommax/ -name "*.mk" -o -name "Makefile" | xargs sed -i -E 's/kmod-qca-nss-ecm//g'

find feeds/nss_packages/ -name "Makefile" | xargs sed -i -E 's/\+kmod-qca-nss-ecm//g'
find feeds/nss_packages/ -name "Makefile" | xargs sed -i -E 's/\+kmod-pptp//g'
find package/ -name "Makefile" | xargs sed -i -E 's/\+kmod-qca-nss-ecm//g'

sed -i '/CONFIG_PACKAGE_kmod-br-netfilter/d' .config
echo 'CONFIG_PACKAGE_kmod-br-netfilter=y' >> .config
sed -i '/CONFIG_KERNEL_SKB_EXTENSIONS/d' .config
echo 'CONFIG_KERNEL_SKB_EXTENSIONS=y' >> .config

find target/linux/qualcommax -name "config-*" | while read cfg; do
    sed -i '/CONFIG_NF_CONNTRACK_DSCPREMARK_EXT/d' "$cfg"
    echo '# CONFIG_NF_CONNTRACK_DSCPREMARK_EXT is not set' >> "$cfg"
done

mkdir -p package/base-files/files/etc/modprobe.d/
cat << 'EOF' > package/base-files/files/etc/modprobe.d/10-ath11k-nss.conf
options ath11k nss_offload=0
options ath11k_ahb nss_offload=0
blacklist qca_nss_ecm
EOF

NFT_PATCH_DIR="package/network/utils/nftables/patches"
if [ -d "$NFT_PATCH_DIR" ]; then
    grep -l "nft_fullcone_attributes" $NFT_PATCH_DIR/*.patch 2>/dev/null | xargs -r rm -f
fi
find package/ -type f -iname "*fullcone*.patch" | xargs -r rm -f
sed -i '/CONFIG_PACKAGE_kmod-nft-fullcone/d' .config
echo '# CONFIG_PACKAGE_kmod-nft-fullcone is not set' >> .config

mkdir -p package/base-files/files/etc/uci-defaults/
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-firstboot-stealth-init
#!/bin/sh

uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

uci set network.lan.ipaddr='172.18.16.1'
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
uci -q set wireless.@wifi-iface[0].key='12345678' || uci -q set wireless.default_radio0.key='12345678'

uci -q set wireless.@wifi-device[1].country='CN' || uci -q set wireless.radio1.country='CN'
uci -q set wireless.@wifi-iface[1].ssid='Home-2.4G' || uci -q set wireless.default_radio1.ssid='Home-2.4G'
uci -q set wireless.@wifi-iface[1].encryption='psk2+ccmp' || uci -q set wireless.default_radio1.encryption='psk2+ccmp'
uci -q set wireless.@wifi-iface[1].key='12345678' || uci -q set wireless.default_radio1.key='12345678'
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
