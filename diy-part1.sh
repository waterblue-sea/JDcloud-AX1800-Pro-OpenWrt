#!/bin/bash

find . -type f -not -path "*/\.git/*" -not -path "*/\.svn/*" -exec sed -i '/0001-QUIC-Add-support-for-BoringSSL-QUIC-APIs\.patch/d' {} +
