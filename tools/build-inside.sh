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
    case $tool in tmux | neovim | fish | starship | ripgrep | eza | bat | fd | fzf | zoxide | delta | procs | mcfly | gdb | cgdb | valgrind | git | cmake) ;; *)
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
    eza) rust_tool eza 0.23.5 eza ;;
    bat) rust_tool bat 0.26.1 bat ;;
    fd) rust_tool fd-find 10.5.0 fd ;;
    zoxide) rust_tool zoxide 0.10.0 zoxide ;;
    delta) rust_tool git-delta 0.19.2 delta ;;
    procs) rust_tool procs 0.14.12 procs ;;
    mcfly) rust_tool mcfly 0.9.4 mcfly ;;
    gdb)
        fetch gdb-17.2 https://sourceware.org/pub/gdb/releases/gdb-17.2.tar.xz
        mkdir build
        cd build
        LDFLAGS=-static ../configure --prefix="$prefix" --disable-shared --enable-static \
            --disable-binutils --disable-gas --disable-gold --disable-ld --disable-gprof \
            --disable-gprofng --disable-sim --disable-gdbserver --disable-nls --disable-werror \
            --without-python --without-guile --without-debuginfod --without-intel-pt \
            --without-babeltrace --without-lzma --without-zstd --with-expat --enable-tui
        make -j"$JOBS" all-gdb
        # The top-level recursive make filters linker overrides. Relink the
        # final executable directly: libtool needs -all-static for system libs.
        make -C gdb -W gdb.o gdb LDFLAGS=-all-static
        make DESTDIR="$stage" install-gdb
        echo 'gdb 17.2' >>"$out/VERSIONS"
        ;;
    cgdb)
        fetch cgdb-0.8.0 https://cgdb.me/files/cgdb-0.8.0.tar.gz
        # Its readline probe predates GCC 14's rejection of implicit int.
        sed -i 's/^main()$/int main(void)/' configure
        LDFLAGS=-static ./configure --prefix="$prefix"
        make -j"$JOBS"
        make DESTDIR="$stage" install
        echo 'cgdb 0.8.0' >>"$out/VERSIONS"
        ;;
    git)
        # Build a private libcurl without libidn2/gnulib's conflicting error()
        # symbol. HTTPS retains OpenSSL and zlib, with no shared dependencies.
        fetch curl-8.22.0 https://curl.se/download/curl-8.22.0.tar.xz
        ./configure --prefix="$stage/git-deps" --disable-shared --enable-static \
            --with-openssl --without-libidn2 --without-libpsl --without-brotli \
            --without-zstd --without-nghttp2 --without-nghttp3 --without-ngtcp2 \
            --without-librtmp --without-libssh2 --disable-ldap --disable-ldaps \
            --disable-docs --disable-manual --with-ca-bundle="$prefix/share/certs/ca-certificates.crt"
        make -j"$JOBS" -C lib
        make -C lib install
        make -C include install
        fetch git-2.55.0 https://www.kernel.org/pub/software/scm/git/git-2.55.0.tar.xz
        git_options=(prefix="$prefix" LDFLAGS=-static NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 \
            NO_PYTHON=1 NO_RUST=1 NO_REGEX=NeedsStartEnd NO_INSTALL_HARDLINKS=1 \
            CURL_CFLAGS="-I$stage/git-deps/include" \
            CURL_LIBCURL="$stage/git-deps/lib/libcurl.a -lssl -lcrypto -lz -lpthread")
        make -j"$JOBS" "${git_options[@]}" all
        make "${git_options[@]}" DESTDIR="$stage" install
        mkdir -p "$out/etc"
        printf '[http]\n\tsslCAInfo = %s/share/certs/ca-certificates.crt\n' "$prefix" >"$out/etc/gitconfig"
        echo 'git 2.55.0' >>"$out/VERSIONS"
        echo 'git-libcurl 8.22.0' >>"$out/VERSIONS"
        ;;
    cmake)
        fetch cmake-4.4.3 https://github.com/Kitware/CMake/releases/download/v4.4.3/cmake-4.4.3.tar.gz
        cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_EXE_LINKER_FLAGS=-static \
            -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_USE_OPENSSL=ON \
            -DOPENSSL_USE_STATIC_LIBS=TRUE -DCMAKE_USE_SYSTEM_LIBRARIES=OFF \
            -DCMAKE_DISABLE_FIND_PACKAGE_Libidn2=TRUE \
            -DCURL_CA_BUNDLE="$prefix/share/certs/ca-certificates.crt" -DBUILD_CursesDialog=OFF
        cmake --build build -j "$JOBS"
        DESTDIR="$stage" cmake --install build
        echo 'cmake 4.4.3' >>"$out/VERSIONS"
        ;;
    valgrind)
        tar xzf /work/build/valgrind-prefix.tar.gz -C "$stage"
        sha256sum /work/build/sources/valgrind-3.27.1.tar.gz >>"$out/SOURCES.sha256"
        echo 'valgrind 3.27.1' >>"$out/VERSIONS"
        ;;
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
