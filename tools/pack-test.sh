#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
mkdir -p "$root"/{bin,dev,proc,sys,tmp,root,etc}
printf 'root:x:0:0:root:/root:/bin/sh\n' >"$root/etc/passwd"
printf 'root:x:0:\n' >"$root/etc/group"
cp /bin/busybox.static "$root/bin/busybox"
for app in sh mount mkdir cat grep uname poweroff sleep env printf test; do
    ln -s busybox "$root/bin/$app"
done
tar xzf /work/dist/modern-linux-x86_64.tar.gz -C "$root"
cd "$root/opt/modern-linux"
sha256sum -c SHA256SUMS >/dev/null
bash /work/tools/audit-static.sh "$root/opt/modern-linux"
gcc -g -O0 -static -march=x86-64 /work/tools/memory-smoke.c -o "$root/debug-smoke"
gcc -O2 -static -march=x86-64 /work/tools/cgdb-smoke.c -lutil -o "$root/cgdb-smoke"
mkdir -p "$root/work/tools"
cp /work/tools/memory-smoke.c "$root/work/tools/"
if sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//' list.txt | grep -qx valgrind; then
    cp -a /valgrind-test/lib64 "$root/"
    cp /valgrind-test/memory-smoke "$root/memory-smoke"
fi
cp /work/tools/guest-init "$root/init"
cp /work/tools/nvim-smoke.lua "$root/nvim-smoke.lua"
chmod 755 "$root/init"
cd "$root"
find . -print0 | cpio --null -o -H newc | gzip -1 >/work/build/kernel-test/initramfs.gz
