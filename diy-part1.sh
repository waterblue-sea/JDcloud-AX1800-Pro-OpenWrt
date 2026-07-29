#!/bin/bash

find . -type f -not -path "*/\.git/*" -not -path "*/\.svn/*" -exec sed -i -E '/sbwml.*(QUIC|\.patch)/Id' {} +
find . -type f -not -path "*/\.git/*" -not -path "*/\.svn/*" -exec sed -i '/Downloading OpenSSL QUIC patches/d' {} +
