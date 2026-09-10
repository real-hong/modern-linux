#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
engine=${ENGINE:-podman}
mkdir -p build/gcc/kernel-test
rm -f build/gcc/kernel-test/PASS
"$engine" build --network=host -t localhost/modern-linux-kernel-test -f tools/Containerfile.test .
"$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD:/work:ro" docker.io/library/centos:7 bash -c \
	'tar xzf /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz -C / && cd /opt/gcc-16.2.0 && sha256sum -c SHA256SUMS >/dev/null && sh /work/tools/gcc-smoke.sh' \
	2>&1 | tee build/gcc/container-test.log
"$engine" run --rm --network=none --security-opt label=disable --user 12345:12345 \
	-e HOME=/tmp/gcc-user -v "$PWD:/work:ro" docker.io/library/centos:7 bash -c \
	'set -eu; test "$(id -u)" != 0; test ! -e /opt/gcc-16.2.0; mkdir -p "$HOME/toolchain"; tar xzf /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz -C "$HOME/toolchain" --strip-components=2; mv "$HOME/toolchain" "$HOME/relocated-gcc"; source "$HOME/relocated-gcc/env.sh"; cd "$HOME/relocated-gcc"; sha256sum -c SHA256SUMS >/dev/null; export GCC_ROOT="$PWD"; bash /work/tools/gcc-smoke.sh' \
	2>&1 | tee build/gcc/unprivileged-test.log
"$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD:/work" localhost/modern-linux-kernel-test bash /work/tools/pack-gcc-test.sh
timeout 600 "$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD/build/gcc/kernel-test:/test:ro" localhost/modern-linux-kernel-test \
	qemu-system-x86_64 -accel tcg -cpu qemu64 -m 4096 -smp 2 \
	-display none -monitor none -serial stdio -no-reboot -nic none \
	-device virtio-rng-pci -kernel /vmlinuz -initrd /test/initramfs.gz \
	-append 'console=ttyS0 rdinit=/init panic=1' 2>&1 | tee build/gcc/kernel-test/serial.log
grep -q '^GCC_CENTOS7_KERNEL_PASS' build/gcc/kernel-test/serial.log
sha256sum dist/gcc-16.2.0-centos7-x86_64.tar.gz >build/gcc/kernel-test/PASS
