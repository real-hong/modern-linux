#!/usr/bin/env bash
set -euo pipefail
base=/work/build/kitty
prefix=$base/package/opt/kitty-0.48.2
deps=$base/deps
mkdir -p "$base/obj" "$deps" "$prefix"
if [[ ! -d $base/bootstrap/opt/gcc-16.2.0 ]]; then
    mkdir -p "$base/bootstrap"
    tar xzf /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz -C "$base/bootstrap"
fi
ln -sfn "$base/bootstrap/opt/gcc-16.2.0" /opt/gcc-16.2.0
. /opt/gcc-16.2.0/env.sh
export CC=gcc CXX=g++
export CFLAGS='--sysroot=/ -O2 -march=x86-64 -mtune=generic -fPIC'
export CXXFLAGS="$CFLAGS"
export LDFLAGS="--sysroot=/ -L$deps/lib"
export LD_LIBRARY_PATH="$deps/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$deps/lib/pkgconfig"
export CGO_ENABLED=0 GOAMD64=v1
export GOCACHE="$base/go-cache" GOMODCACHE="$base/go-mod-cache" GOTOOLCHAIN=local
jobs=${JOBS:-10}
for archive in "$base"/sources/*.tar.*; do
    tar xf "$archive" -C "$base/src" --skip-old-files
done
if [[ ! -f $deps/lib/libssl.so.3 ]]; then
    cd "$base/src/openssl-3.5.2"
    ./Configure linux-x86_64 shared --prefix="$deps" --libdir=lib --openssldir=/etc/pki/tls
    make -j "$jobs"
    make install_sw
fi
if [[ ! -f $deps/lib/libxxhash.so ]]; then
    make -C "$base/src/xxHash-0.8.3" -j "$jobs" PREFIX="$deps"
    make -C "$base/src/xxHash-0.8.3" PREFIX="$deps" install
fi
if [[ ! -f $deps/bin/python3.12 ]]; then
    tar xf "$base/sources/Python-3.12.10.tar.xz" -C "$base/src"
    mkdir -p "$base/obj/python"
    cd "$base/obj/python"
    "$base/src/Python-3.12.10/configure" --prefix="$deps" --enable-shared --without-ensurepip \
        --disable-test-modules --with-openssl="$deps" --with-openssl-rpath=no
    make -j "$jobs"
    make install
fi
export PATH="$deps/bin:/usr/local/go/bin:$PATH"
export PYTHONHOME="$deps"
if [[ ! -x $base/src/ninja-1.12.1/ninja ]]; then
    (cd "$base/src/ninja-1.12.1"; python3.12 configure.py --bootstrap)
fi
export PATH="$base/src/ninja-1.12.1:$PATH"
if [[ ! -f $deps/.xkb-system-data-v2 ]]; then
    python3.12 "$base/src/meson-1.7.0/meson.py" setup --reconfigure "$base/obj/xkbcommon" "$base/src/libxkbcommon-xkbcommon-1.8.1" \
        --prefix="$deps" --libdir=lib -Denable-wayland=false -Denable-docs=false -Denable-tools=false -Denable-xkbregistry=false -Dxkb-config-root=/usr/share/X11/xkb -Dxkb-config-extra-path=/etc/xkb -Dx-locale-root=/usr/share/X11/locale
    ninja -C "$base/obj/xkbcommon" -j "$jobs"
    ninja -C "$base/obj/xkbcommon" install
    touch "$deps/.xkb-system-data-v2"
fi
if [[ ! -f $deps/.dbus-system-paths ]]; then
    cd "$base/src/dbus-1.14.10"
    ./configure --prefix="$deps" --libdir="$deps/lib" --sysconfdir=/etc --localstatedir=/var --disable-static \
        --disable-tests --disable-doxygen-docs --disable-xml-docs --disable-systemd \
        --disable-selinux --disable-libaudit --without-x
    make -j "$jobs"
    make install
    touch "$deps/.dbus-system-paths"
fi
if [[ ! -f $deps/lib/libfreetype.so ]]; then
    cd "$base/src/freetype-2.13.3"
    ./configure --prefix="$deps" --disable-static --with-harfbuzz=no --with-brotli=no
    make -j "$jobs"
    make install
fi
if [[ ! -f $deps/lib/libharfbuzz.so ]]; then
    python3.12 "$base/src/meson-1.7.0/meson.py" setup "$base/obj/harfbuzz" "$base/src/harfbuzz-8.5.0" \
        --prefix="$deps" --libdir=lib -Dglib=disabled -Dgobject=disabled -Dcairo=disabled \
        -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled -Dicu=disabled -Dfreetype=enabled
    ninja -C "$base/obj/harfbuzz" -j "$jobs"
    ninja -C "$base/obj/harfbuzz" install
fi
if [[ ! -f $deps/lib/libpixman-1.so ]]; then
    python3.12 "$base/src/meson-1.7.0/meson.py" setup "$base/obj/pixman" "$base/src/pixman-0.44.2" \
        --prefix="$deps" --libdir=lib -Dtests=disabled -Ddemos=disabled -Dgtk=disabled
    ninja -C "$base/obj/pixman" -j "$jobs"
    ninja -C "$base/obj/pixman" install
fi
if [[ ! -f $deps/lib/libcairo.so ]]; then
    python3.12 "$base/src/meson-1.7.0/meson.py" setup "$base/obj/cairo" "$base/src/cairo-1.18.4" \
        --prefix="$deps" --libdir=lib --wrap-mode=nofallback -Dtests=disabled -Dglib=disabled \
        -Dxlib=disabled -Dxcb=disabled -Dspectre=disabled -Dsymbol-lookup=disabled
    ninja -C "$base/obj/cairo" -j "$jobs"
    ninja -C "$base/obj/cairo" install
fi
bash /work/tools/build-kitty-mesa.sh
export CPPFLAGS='-DSET_PYTHON_HOME=\"../kitty-python\"'
export CFLAGS="$CFLAGS -I$base/src/simde-0.8.2 -I$deps/include/freetype2 -I$deps/include/harfbuzz -I$deps/include/cairo"
# Inherited RPATH finds the bundled libraries without changing child environments.
export LDFLAGS="$LDFLAGS -Wl,--disable-new-dtags -Wl,-rpath,\$ORIGIN/../lib/kitty-runtime:\$ORIGIN/../lib/kitty-python/lib"
mkdir -p "$prefix/lib/kitty-python/lib"
cp -a "$deps/lib/python3.12" "$prefix/lib/kitty-python/lib/"
cd "$base/src/kitty-0.48.2"
cmp -s /work/tools/kitty-centos7-compat.h glfw/kitty-centos7-compat.h || \
    cp /work/tools/kitty-centos7-compat.h glfw/kitty-centos7-compat.h
python3.12 - <<'PYCOMPAT'
from pathlib import Path
path = Path('glfw/x11_window.c')
text = path.read_text()
anchor = '#include <assert.h>'
include = '#include "kitty-centos7-compat.h"'
if include not in text:
    if anchor not in text:
        raise SystemExit('Unexpected GLFW include layout')
    path.write_text(text.replace(anchor, anchor + '\n' + include))
path = Path('kitty/disk-cache.c')
text = path.read_text()
anchor = '#include <time.h>'
include = '#include "../glfw/kitty-centos7-compat.h"'
if include not in text:
    if anchor not in text:
        raise SystemExit('Unexpected disk cache include layout')
    path.write_text(text.replace(anchor, anchor + '\n' + include))
PYCOMPAT
mkdir -p fonts
cp "$base/sources/SymbolsNerdFontMono-Regular.ttf" fonts/
python3.12 setup.py --prefix "$prefix" --vcs-rev v0.48.2 --ignore-compiler-warnings linux-package
