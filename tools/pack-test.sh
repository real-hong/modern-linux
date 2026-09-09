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
while IFS= read -r -d '' binary; do
    readelf -h "$binary" >/dev/null
    if readelf -lW "$binary" | grep INTERP >/dev/null || readelf -dW "$binary" | grep '(NEEDED)' >/dev/null; then
        echo "Not static: $binary" >&2
        exit 1
    fi
done < <(find bin -type f -print0)
cp /work/tools/guest-init "$root/init"
cp /work/tools/nvim-smoke.lua "$root/nvim-smoke.lua"
chmod 755 "$root/init"
cd "$root"
find . -print0 | cpio --null -o -H newc | gzip -1 >/work/build/kernel-test/initramfs.gz
