#!/usr/bin/env bash
set -euo pipefail
cp /boot/vmlinuz-3.10.0-1160.el7.x86_64 /work/build/kitty/kernel-test/vmlinuz
cp /work/tools/kitty-guest-init /init
cp /work/tools/kitty-smoke.sh /kitty-smoke.sh
chmod 755 /init
tar xzf /work/dist/kitty-0.48.2-centos7-x86_64.tar.gz -C /
cd /
find . -path ./proc -prune -o -path ./sys -prune -o -path ./dev -prune -o \
    -path ./work -prune -o -path ./usr/lib/firmware -prune -o -path ./boot -prune -o \
    -path ./var/cache -prune -o -print0 | cpio --null -o -H newc | gzip -1 >/work/build/kitty/kernel-test/initramfs.gz
