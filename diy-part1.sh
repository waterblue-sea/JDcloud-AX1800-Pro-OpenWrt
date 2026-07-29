cat << 'EOF' > scripts/prepare_dependencies.sh
#!/bin/bash
OPENWRT_BRANCH="openwrt-23.05"

clone_repo() {
    local repo_url=$1; local target_dir=$2; local branch=$3; shift 3; local git_params=("$@")
    if [ ! -d "$target_dir/.git" ]; then
        git clone "${git_params[@]}" "$repo_url" "$target_dir" -b "$branch"
    fi
}

replace_dependency_with_repo() {
    local target_dir=$1; local repo_url=$2; local branch=$3; shift 3; local git_params=("$@")
    rm -rf "$target_dir"
    git clone "${git_params[@]}" "$repo_url" "$target_dir" -b "$branch"
}

replace_dependency_from_repo() {
    local target_dir=$1; local temp_repo=$2; local repo_url=$3; local branch=$4; shift 4; local git_params=("$@")
    rm -rf "$target_dir"
    clone_repo "$repo_url" "$temp_repo" "$branch" "${git_params[@]}"
    cp -a "$temp_repo/package/libs/openssl" "$target_dir"
}

replace_dependency_with_repo "feeds/packages/net/curl" "https://github.com/sbwml/feeds_packages_net_curl" "main"
replace_dependency_with_repo "package/libs/ngtcp2" "https://github.com/sbwml/package_libs_ngtcp2" "main"
replace_dependency_with_repo "package/libs/nghttp3" "https://github.com/sbwml/package_libs_nghttp3" "main"
replace_dependency_from_repo "package/libs/openssl" "temp_openwrt" "https://github.com/openwrt/openwrt" "$OPENWRT_BRANCH" --depth=1

touch prepare_dependencies.stamp
./scripts/feeds install -a
echo "All dependencies prepared cleanly."
EOF

chmod +x scripts/prepare_dependencies.sh
