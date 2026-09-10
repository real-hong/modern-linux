#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
engine=${ENGINE:-podman}
mkdir -p build/llvm/kernel-test
rm -f build/llvm/kernel-test/PASS
"$engine" build --network=host -t localhost/modern-linux-kernel-test -f tools/Containerfile.test .
"$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD:/work:ro" docker.io/library/centos:7 bash -c \
	'set -eu; tar xzf /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz -C /; cd /opt/llvm-23.1.1; sha256sum -c SHA256SUMS >/dev/null; sh /work/tools/llvm-smoke.sh; sh /work/tools/compiler-rt-smoke.sh' \
	2>&1 | tee build/llvm/container-test.log
"$engine" run --rm --network=none --security-opt label=disable --user 12345:12345 \
	-e HOME=/tmp/llvm-user -v "$PWD:/work:ro" docker.io/library/centos:7 bash -c \
	'set -eu; test "$(id -u)" != 0; test ! -e /opt/llvm-23.1.1; test ! -e /opt/gcc-16.2.0; mkdir -p "$HOME/toolchain"; tar xzf /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz -C "$HOME/toolchain" --strip-components=2; mv "$HOME/toolchain" "$HOME/relocated-llvm"; source "$HOME/relocated-llvm/env.sh"; cd "$HOME/relocated-llvm"; sha256sum -c SHA256SUMS >/dev/null; export LLVM_ROOT="$PWD"; bash /work/tools/llvm-smoke.sh; bash /work/tools/llvm-cmake-smoke.sh; sh /work/tools/compiler-rt-smoke.sh' \
	2>&1 | tee build/llvm/unprivileged-test.log
"$engine" run --rm --network=none --security-opt label=disable --user 12345:12345 \
	-v "$PWD:/work:ro" docker.io/library/centos:7 bash -c \
	'set -eu; mkdir -p /tmp/fish-llvm; tar xzf /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz -C /tmp/fish-llvm --strip-components=2; tar xOf /work/dist/modern-linux-x86_64.tar.gz opt/modern-linux/bin/fish >/tmp/fish; chmod +x /tmp/fish; /tmp/fish --no-config /work/tools/llvm-fish-smoke.fish /tmp/fish-llvm' \
	2>&1 | tee build/llvm/fish-test.log
"$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD:/work" localhost/modern-linux-kernel-test bash /work/tools/pack-llvm-test.sh
timeout 900 "$engine" run --rm --network=none --security-opt label=disable \
	-v "$PWD/build/llvm/kernel-test:/test:ro" localhost/modern-linux-kernel-test \
	qemu-system-x86_64 -accel tcg -cpu qemu64 -m 6144 -smp 2 \
	-display none -monitor none -serial stdio -no-reboot -nic none \
	-device virtio-rng-pci -kernel /vmlinuz -initrd /test/initramfs.gz \
	-append 'console=ttyS0 rdinit=/init panic=1' 2>&1 | tee build/llvm/kernel-test/serial.log
grep -q '^LLVM_CENTOS7_KERNEL_PASS' build/llvm/kernel-test/serial.log
sha256sum dist/llvm-23.1.1-centos7-x86_64.tar.gz >build/llvm/kernel-test/PASS
