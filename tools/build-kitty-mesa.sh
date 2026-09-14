#!/usr/bin/env bash
set -euo pipefail
base=/work/build/kitty
export PATH="$base/deps/bin:$base/src/ninja-1.12.1:/opt/gcc-16.2.0/bin:$PATH"
export PYTHONHOME="$base/deps"
export PYTHONPATH="$base/src/mako-1.3.10:$base/src/MarkupSafe-2.1.5/src"
# Mesa 21's version probe predates Python 3.12's removal of distutils.
python3.12 - "$base/src/mesa-21.3.9/meson.build" <<'PYFIX'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text().replace('from distutils.version import StrictVersion\n', '')
s = s.replace('assert StrictVersion(mako.__version__) > StrictVersion("0.8.0")', 'assert tuple(map(int, mako.__version__.split("."))) > (0, 8, 0)')
p.write_text(s)
PYFIX
if [[ ! -f $base/mesa/lib/libGL.so ]]; then
    python3.12 "$base/src/meson-1.7.0/meson.py" setup "$base/obj/mesa" "$base/src/mesa-21.3.9" \
        --prefix="$base/mesa" --libdir=lib --wrap-mode=nofallback \
        -Dplatforms=x11 -Dgallium-drivers=swrast -Dvulkan-drivers= -Ddri-drivers= \
        -Dglx=gallium-xlib -Dllvm=disabled -Degl=disabled -Dgbm=disabled \
        -Dgles1=disabled -Dgles2=disabled -Dshared-glapi=enabled -Dbuild-tests=false
    ninja -C "$base/obj/mesa" -j "${JOBS:-10}"
    ninja -C "$base/obj/mesa" install
fi
