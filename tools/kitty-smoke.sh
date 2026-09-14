#!/usr/bin/env bash
set -euo pipefail
root=${KITTY_ROOT:-/opt/kitty-0.48.2}
"$root/bin/kitty" --version | grep -F '0.48.2'
"$root/bin/kitten" --version | grep -F '0.48.2'
"$root/bin/kitty" +runpy 'import ssl, bz2, ctypes, zlib, kitty.fast_data_types; print(ssl.OPENSSL_VERSION); print("KITTY_PYTHON_PASS")'
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 LANG=en_US.UTF-8
Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset -ac >/tmp/kitty-xvfb.log 2>&1 &
xpid=$!
trap 'kill "$xpid" 2>/dev/null || true' EXIT
for i in {1..30}; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 1
done
rm -f /tmp/kitty-pty-pass /tmp/kitty-child-kernel
if ! timeout 90 "$root/bin/kitty-software" --config NONE -o linux_display_server=x11 \
    /bin/sh -c 'test -t 0 && test -t 1 && test -z "${LD_LIBRARY_PATH+x}" && echo KITTY_PTY_PASS >/tmp/kitty-pty-pass; uname -r >/tmp/kitty-child-kernel; printf "kitty CentOS7 rendering test\n"; sleep 3' >/tmp/kitty-gui.log 2>&1; then
    cat /tmp/kitty-gui.log /tmp/kitty-xvfb.log
    exit 1
fi
cat /tmp/kitty-gui.log /tmp/kitty-child-kernel
if grep -Eq 'Failed to create XKB compose table|Failed to initialize XKB context' /tmp/kitty-gui.log; then
    exit 1
fi
grep -qx KITTY_PTY_PASS /tmp/kitty-pty-pass
echo KITTY_GUI_SMOKE_PASS
