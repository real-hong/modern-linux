#!/usr/bin/env bash
set -euo pipefail
version=3.27.1
archive=/work/build/sources/valgrind-$version.tar.gz
mkdir -p /work/build/sources
if [[ ! -f $archive ]]; then
    curl -fL --retry 5 "https://sourceware.org/pub/valgrind/valgrind-$version.tar.bz2" -o "$archive.part"
    mv "$archive.part" "$archive"
fi
src=$(mktemp -d /work/build/valgrind-source.XXXXXX)
stage=$(mktemp -d /work/build/valgrind-stage.XXXXXX)
tar xf "$archive" -C "$src" --strip-components=1
cd "$src"
export CFLAGS='-O2 -march=x86-64 -mtune=generic'
export CXXFLAGS="$CFLAGS"
./configure --prefix=/opt/modern-linux --enable-only64 --without-mpicc
# The tool engines are already freestanding static executables. Keep the
# launchers static too, while preserving the required glibc preload modules.
link_options=(valgrind_LDFLAGS=-static vgdb_LDFLAGS=-static \
    valgrind_listener_LDFLAGS=-static valgrind_di_server_LDFLAGS=-static \
    getoff_amd64_linux_LDFLAGS=-static)
make -j"${JOBS:-4}" "${link_options[@]}"
make "${link_options[@]}" DESTDIR="$stage" install
gcc --version >"$stage/opt/modern-linux/VALGRIND-TOOLCHAIN"
tar czf /work/build/valgrind-prefix.tar.gz.part -C "$stage" opt
mv /work/build/valgrind-prefix.tar.gz.part /work/build/valgrind-prefix.tar.gz
