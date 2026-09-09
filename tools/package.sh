#!/usr/bin/env bash
set -euo pipefail
stage=${1:?Usage: package.sh /work/build/stage.NAME}
[[ $stage == /work/build/stage.* && -d $stage/opt/modern-linux/bin ]] || exit 1
out=$stage/opt/modern-linux
rm -rf "$out/share/terminfo"
cp -aL /usr/share/terminfo "$out/share/"
cp /work/list.txt "$out/list.txt"
install -Dm644 /etc/ssl/certs/ca-certificates.crt "$out/share/certs/ca-certificates.crt"
bash /work/tools/audit-static.sh "$out"
# shellcheck disable=SC2016 # Expand PATH when the user sources env.sh.
printf 'export PATH="/opt/modern-linux/bin:$PATH"\nexport TERMINFO=/opt/modern-linux/share/terminfo\n' >"$out/env.sh"
cd "$out"
find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >"$stage/checksums"
mv "$stage/checksums" SHA256SUMS
cd "$stage"
tar czf /work/dist/modern-linux-x86_64.tar.gz.part opt
mv /work/dist/modern-linux-x86_64.tar.gz.part /work/dist/modern-linux-x86_64.tar.gz
rm -f /work/build/kernel-test/PASS
printf 'Static ELF audit passed. Run ./build.sh test for the CentOS 7 kernel check.\n'
