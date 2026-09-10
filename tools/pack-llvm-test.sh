#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
mkdir -p "$root"/{bin,dev,proc,sys,tmp,root,etc,lib64}
cp /bin/busybox.static "$root/bin/busybox"
for app in sh mount mkdir cat grep uname poweroff sleep env; do
	ln -s busybox "$root/bin/$app"
done
tar xzf /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz -C "$root"
cp -L "$root/opt/llvm-23.1.1/sysroot/lib64/"* "$root/lib64/"
cp /work/tools/llvm-guest-init "$root/init"
cp /work/tools/llvm-smoke.sh "$root/llvm-smoke.sh"
cp /work/tools/compiler-rt-smoke.sh "$root/compiler-rt-smoke.sh"
chmod 755 "$root/init"
cd "$root"
find . -print0 | cpio --null -o -H newc | gzip -1 >/work/build/llvm/kernel-test/initramfs.gz
