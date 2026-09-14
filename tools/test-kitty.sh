#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
engine=${ENGINE:-podman}
mkdir -p build/kitty/kernel-test
rm -f build/kitty/kernel-test/PASS
"$engine" build --network=host -t localhost/modern-linux-kitty-test -f tools/Containerfile.kitty-test .
"$engine" run --rm --network=none --security-opt label=disable --user 12345:12345 \
    -e HOME=/tmp/kitty-user -v "$PWD:/work:ro" localhost/modern-linux-kitty-test bash -c \
    'set -eu; mkdir -p "$HOME/original"; tar xzf /work/dist/kitty-0.48.2-centos7-x86_64.tar.gz -C "$HOME/original" --strip-components=2; mv "$HOME/original" "$HOME/relocated kitty"; export KITTY_ROOT="$HOME/relocated kitty"; cd "$KITTY_ROOT"; sha256sum -c SHA256SUMS >/dev/null; bash /work/tools/kitty-smoke.sh' \
    2>&1 | tee build/kitty/unprivileged-test.log
"$engine" build --network=host -t localhost/modern-linux-kernel-test -f tools/Containerfile.test .
"$engine" run --rm --network=none --security-opt label=disable -v "$PWD:/work" \
    localhost/modern-linux-kitty-test bash /work/tools/pack-kitty-test.sh
timeout 600 "$engine" run --rm --network=none --security-opt label=disable \
    -v "$PWD/build/kitty/kernel-test:/test:ro" localhost/modern-linux-kernel-test \
    qemu-system-x86_64 -accel tcg -cpu qemu64 -m 3072 -smp 2 -display none \
    -monitor none -serial stdio -no-reboot -nic none -device virtio-rng-pci \
    -kernel /test/vmlinuz -initrd /test/initramfs.gz \
    -append 'console=ttyS0 rdinit=/init panic=1' 2>&1 | tee build/kitty/kernel-test/serial.log
grep -q '^KITTY_CENTOS7_KERNEL_PASS' build/kitty/kernel-test/serial.log
sha256sum dist/kitty-0.48.2-centos7-x86_64.tar.gz >build/kitty/kernel-test/PASS
