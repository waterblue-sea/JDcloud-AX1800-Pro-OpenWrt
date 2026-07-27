#!/bin/bash

find . -type f -exec grep -lE "sbwml|0001-QUIC|temp_openwrt|package_libs_nghttp3" {} + | \
xargs -r sed -i -E '/sbwml|0001-QUIC|temp_openwrt|package_libs_nghttp3/d'
