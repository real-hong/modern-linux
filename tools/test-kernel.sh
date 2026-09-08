#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
engine=${ENGINE:-podman}
[[ -f dist/modern-linux-x86_64.tar.gz ]] || {
    echo 'Build the package first' >&2
    exit 1
}
mkdir -p build/kernel-test
# Avoid stale success records being mistaken for this run's result.
rm -f build/kernel-test/PASS
"$engine" build --network=host -t localhost/modern-linux-kernel-test -f tools/Containerfile.test .
"$engine" run --rm --network=none --security-opt label=disable \
    -v "$PWD:/work" localhost/modern-linux-kernel-test bash /work/tools/pack-test.sh
timeout 300 "$engine" run --rm --network=none --security-opt label=disable \
    -v "$PWD/build/kernel-test:/test:ro" localhost/modern-linux-kernel-test \
    qemu-system-x86_64 -accel tcg -cpu qemu64 -m 2048 -smp 2 \
    -display none -monitor none -serial stdio -no-reboot -nic none \
    -device virtio-rng-pci -kernel /vmlinuz -initrd /test/initramfs.gz \
    -append 'console=ttyS0 rdinit=/init panic=1' 2>&1 | tee build/kernel-test/serial.log
grep -q '^MODERN_LINUX_CENTOS7_PASS' build/kernel-test/serial.log
sha256sum dist/modern-linux-x86_64.tar.gz >build/kernel-test/PASS
echo 'Static executables passed smoke tests on the real CentOS 7 3.10.0-1160.el7.x86_64 kernel.'
