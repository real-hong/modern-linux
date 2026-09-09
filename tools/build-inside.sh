#!/usr/bin/env bash
set -euo pipefail
export CFLAGS='-O2 -march=x86-64 -mtune=generic'
export CXXFLAGS="$CFLAGS"
export RUSTFLAGS='-C target-feature=+crt-static -C target-cpu=x86-64'
export CARGO_BUILD_TARGET=x86_64-unknown-linux-musl
export CARGO_HOME=/work/build/cargo
export CARGO_TARGET_DIR=/work/build/cargo-target
export CARGO_BUILD_JOBS=${JOBS:-4}
export PKG_CONFIG_ALL_STATIC=1 OPENSSL_STATIC=1 LIBZ_SYS_STATIC=1
export CGO_ENABLED=0 GOAMD64=v1 GOTOOLCHAIN=local
export GOCACHE=/work/build/go-cache GOPATH=/work/build/go
mkdir -p /work/build/sources
stage=$(mktemp -d /work/build/stage.XXXXXX)
trap 'echo "Build stopped; staging directory: $stage" >&2' ERR
prefix=/opt/modern-linux
out=$stage$prefix
mkdir -p "$out/bin" "$out/share"
{
    rustc --version
    cargo --version
    go version
    cc --version
} >"$out/TOOLCHAIN"
cp /work/tools/releases.json "$out/RELEASES.json"
# Validate the entire list before beginning expensive builds.
mapfile -t requested < <(sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d' /work/list.txt)
((${#requested[@]})) || {
    echo 'Empty list.txt' >&2
    exit 1
}
for tool in "${requested[@]}"; do
    case $tool in tmux | neovim | fish | starship | ripgrep | exa | bat | fd | fzf | zoxide | delta | procs | mcfly) ;; *)
        echo "Unsupported tool: $tool" >&2
        exit 1
        ;;
    esac
done
fetch() {
    local url=$2 archive=/work/build/sources/$1.tar.gz
    if [[ ! -f $archive ]]; then
        curl -fL --retry 5 "$url" -o "$archive.part"
        mv "$archive.part" "$archive"
    fi
    sha256sum "$archive" >>"$out/SOURCES.sha256"
    src=$(mktemp -d /work/build/source.XXXXXX)
    tar xf "$archive" -C "$src" --strip-components=1
    cd "$src"
}
rust_tool() {
    local crate=$1 version=$2 binary=$3
    cargo install "$crate" --version "=$version" --locked --root "$stage/rust" --force
    install -m755 "$stage/rust/bin/$binary" "$out/bin/$binary"
    printf '%s %s\n' "$crate" "$version" >>"$out/VERSIONS"
}
for tool in "${requested[@]}"; do
    echo "===== Building $tool ====="
    case $tool in
    starship) rust_tool starship 1.26.0 starship ;;
    ripgrep) rust_tool ripgrep 15.2.0 rg ;;
    exa) rust_tool exa 0.10.1 exa ;;
    bat) rust_tool bat 0.26.1 bat ;;
    fd) rust_tool fd-find 10.5.0 fd ;;
    zoxide) rust_tool zoxide 0.10.0 zoxide ;;
    delta) rust_tool git-delta 0.19.2 delta ;;
    procs) rust_tool procs 0.14.12 procs ;;
    mcfly) rust_tool mcfly 0.9.4 mcfly ;;
    fzf)
        fetch fzf-0.74.3 https://github.com/junegunn/fzf/archive/refs/tags/v0.74.3.tar.gz
        go build -trimpath -ldflags '-s -w -X main.version=0.74.3' -o "$out/bin/fzf" .
        echo 'fzf 0.74.3' >>"$out/VERSIONS"
        ;;
    tmux)
        fetch tmux-3.7c https://github.com/tmux/tmux/releases/download/3.7c/tmux-3.7c.tar.gz
        LDFLAGS=-static ./configure --prefix="$prefix" --enable-static
        make -j"$JOBS"
        make DESTDIR="$stage" install
        echo 'tmux 3.7c' >>"$out/VERSIONS"
        ;;
    fish)
        fetch fish-4.9.3 https://github.com/fish-shell/fish-shell/releases/download/4.9.3/fish-4.9.3.tar.xz
        cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_SYSCONFDIR="$prefix/etc" \
            -DWITH_DOCS=OFF -DWITH_MESSAGE_LOCALIZATION=OFF \
            -DFISH_USE_SYSTEM_PCRE2=OFF -DRust_CARGO_TARGET="$CARGO_BUILD_TARGET" \
            -DCARGO_FLAGS=--locked
        cmake --build build -j "$JOBS"
        DESTDIR="$stage" cmake --install build
        echo 'fish 4.9.3' >>"$out/VERSIONS"
        ;;
    neovim)
        fetch neovim-0.12.5 https://github.com/neovim/neovim/archive/refs/tags/v0.12.5.tar.gz
        make -j"$JOBS" CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$prefix" \
            DEPS_CMAKE_FLAGS=-DUSE_BUNDLED_TS_PARSERS=OFF \
            CMAKE_EXTRA_FLAGS='-DSTATIC_BUILD=ON -DENABLE_LIBINTL=OFF -DENABLE_LTO=OFF -DCMAKE_EXE_LINKER_FLAGS=-static'
        DESTDIR="$stage" cmake --install build
        echo 'neovim 0.12.5' >>"$out/VERSIONS"
        ;;
    esac
done
bash /work/tools/package.sh "$stage"
