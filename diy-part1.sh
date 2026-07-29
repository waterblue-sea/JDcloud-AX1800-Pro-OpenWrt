#!/bin/bash

sed -i -E 's/^(src-git (packages|luci|routing|telephony).*)\.git[;a-zA-Z0-9_-]*$/\1.git;openwrt-23.05/g' feeds.conf.default

mkdir -p scripts
cat << 'EOF' > scripts/prepare_dependencies.sh
#!/bin/bash
exit 0
EOF
chmod +x scripts/prepare_dependencies.sh
