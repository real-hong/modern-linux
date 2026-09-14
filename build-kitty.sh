#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
engine=${ENGINE:-podman}
case ${1:-all} in all|build|test) mode=${1:-all} ;; *) echo 'Usage: bash build-kitty.sh [all|build|test]' >&2; exit 2 ;; esac
mkdir -p build/kitty/{sources,src} dist
if [[ $mode != test ]]; then
    test -f dist/gcc-16.2.0-centos7-x86_64.tar.gz || { echo 'Build GCC first with bash build-gcc.sh' >&2; exit 1; }
    fetch() {
        if [[ ! -s build/kitty/sources/$2 ]]; then
            curl -fL --retry 5 "$1" -o "build/kitty/sources/$2.part"
            mv "build/kitty/sources/$2.part" "build/kitty/sources/$2"
        fi
    }
    fetch https://github.com/kovidgoyal/kitty/releases/download/v0.48.2/kitty-0.48.2.tar.xz kitty-0.48.2.tar.xz
    fetch https://dbus.freedesktop.org/releases/dbus/dbus-1.14.10.tar.xz dbus-1.14.10.tar.xz
    fetch https://downloads.sourceforge.net/project/freetype/freetype2/2.13.3/freetype-2.13.3.tar.xz freetype-2.13.3.tar.xz
    fetch https://github.com/harfbuzz/harfbuzz/releases/download/8.5.0/harfbuzz-8.5.0.tar.xz harfbuzz-8.5.0.tar.xz
    fetch https://cairographics.org/releases/pixman-0.44.2.tar.gz pixman-0.44.2.tar.gz
    fetch https://archive.mesa3d.org/older-versions/21.x/mesa-21.3.9.tar.xz mesa-21.3.9.tar.xz
    fetch https://files.pythonhosted.org/packages/source/m/mako/mako-1.3.10.tar.gz mako-1.3.10.tar.gz
    fetch https://files.pythonhosted.org/packages/source/M/MarkupSafe/MarkupSafe-2.1.5.tar.gz MarkupSafe-2.1.5.tar.gz
    fetch https://cairographics.org/releases/cairo-1.18.4.tar.xz cairo-1.18.4.tar.xz
    fetch https://www.openssl.org/source/openssl-3.5.2.tar.gz openssl-3.5.2.tar.gz
    fetch https://www.python.org/ftp/python/3.12.10/Python-3.12.10.tar.xz Python-3.12.10.tar.xz
    fetch https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz xxHash-0.8.3.tar.gz
    fetch https://github.com/simd-everywhere/simde/archive/refs/tags/v0.8.2.tar.gz simde-0.8.2.tar.gz
    fetch https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.8.1.tar.gz libxkbcommon-1.8.1.tar.gz
    fetch https://github.com/mesonbuild/meson/releases/download/1.7.0/meson-1.7.0.tar.gz meson-1.7.0.tar.gz
    fetch https://github.com/ninja-build/ninja/archive/refs/tags/v1.12.1.tar.gz ninja-1.12.1.tar.gz
    fetch https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf SymbolsNerdFontMono-Regular.ttf
    fetch https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/LICENSE nerd-fonts-LICENSE
    "$engine" build --network=host -t localhost/modern-linux-gcc-builder -f tools/Containerfile.gcc .
    "$engine" build --network=host -t localhost/modern-linux-kitty-builder -f tools/Containerfile.kitty .
    "$engine" run --rm --network=host --security-opt label=disable -e JOBS="${JOBS:-10}" \
        -v "$PWD:/work" localhost/modern-linux-kitty-builder bash /work/tools/build-kitty-inside.sh
    "$engine" run --rm --network=none --security-opt label=disable \
        -v "$PWD:/work" localhost/modern-linux-kitty-builder bash /work/tools/package-kitty.sh
fi
if [[ $mode != build ]]; then
    ENGINE="$engine" bash tools/test-kitty.sh
fi
