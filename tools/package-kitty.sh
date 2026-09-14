#!/usr/bin/env bash
set -euo pipefail
base=/work/build/kitty
prefix=$base/package/opt/kitty-0.48.2
export LD_LIBRARY_PATH="$base/mesa/lib:$base/deps/lib:$base/bootstrap/opt/gcc-16.2.0/lib64"
export PYTHONHOME="$base/deps"
"$base/deps/bin/python3.12" /work/tools/package-kitty.py
"$base/deps/bin/python3.12" /work/tools/audit-kitty.py "$prefix" | tee "$prefix/ELF-AUDIT.txt"
(cd "$base/sources"; sha256sum *) >"$prefix/SOURCES.sha256"
sha256sum /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz >"$prefix/BUILD-INPUTS.sha256"
(cd "$prefix"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS)
tar czf /work/dist/kitty-0.48.2-centos7-x86_64.tar.gz.part -C "$base/package" opt
mv /work/dist/kitty-0.48.2-centos7-x86_64.tar.gz.part /work/dist/kitty-0.48.2-centos7-x86_64.tar.gz
(cd /work/dist; sha256sum kitty-0.48.2-centos7-x86_64.tar.gz >kitty-0.48.2-centos7-x86_64.tar.gz.sha256)
