#!/bin/bash

sed -i 's/;master/;openwrt-23.05/g' feeds.conf.default
sed -i 's/;main/;openwrt-23.05/g' feeds.conf.default

sed -i -E 's/\.git$/.git;openwrt-23.05/g' feeds.conf.default

mkdir -p scripts
cat << 'EOF' > scripts/prepare_dependencies.sh
#!/bin/bash
exit 0
EOF
chmod +x scripts/prepare_dependencies.sh
