#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
mkdir -p "$root"/{bin,dev,proc,sys,tmp,root,etc,lib64}
cp /bin/busybox.static "$root/bin/busybox"
for app in sh mount mkdir cat grep uname poweroff sleep env; do
	ln -s busybox "$root/bin/$app"
done
tar xzf /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz -C "$root"
cp -L "$root/opt/gcc-16.2.0/sysroot/lib64/"* "$root/lib64/"
cp /work/tools/gcc-guest-init "$root/init"
cp /work/tools/gcc-smoke.sh "$root/gcc-smoke.sh"
chmod 755 "$root/init"
cd "$root"
find . -print0 | cpio --null -o -H newc | gzip -1 >/work/build/gcc/kernel-test/initramfs.gz
