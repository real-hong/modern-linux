#!/usr/bin/env bash
set -euo pipefail
base=/work/build/llvm
prefix=/opt/llvm-23.1.1
gcc_root=/opt/gcc-16.2.0
mkdir -p "$prefix"/{lib64,lib/gcc/x86_64-pc-linux-gnu/16.2.0,include,share/licenses}
cp -a "$gcc_root/sysroot" "$prefix/"
cp -a "$gcc_root/include/c++" "$prefix/include/"
cp -a "$gcc_root/lib/gcc/x86_64-pc-linux-gnu/16.2.0/"{crt*.o,libgcc*} "$prefix/lib/gcc/x86_64-pc-linux-gnu/16.2.0/"
cp -a "$gcc_root/lib64/"{libstdc++.a,libstdc++.so*,libstdc++exp.a,libstdc++fs.a,libstdc++.modules.json,libgcc_s.so*,libatomic.a,libatomic.so*} "$prefix/lib64/"
mkdir -p "$prefix/share/licenses/gcc-runtime"
cp -a "$gcc_root/share/licenses/." "$prefix/share/licenses/gcc-runtime/"
cp "$gcc_root/SYSROOT-RPMS" "$prefix/"
for driver in clang clang++ clang-cpp; do
	cat >"$prefix/bin/$driver.cfg" <<'EOF'
--sysroot=<CFGDIR>/../sysroot
--gcc-install-dir=<CFGDIR>/../lib/gcc/x86_64-pc-linux-gnu/16.2.0
$-Wl,-L,<CFGDIR>/../lib64
EOF
done
cat >"$prefix/env.sh" <<'EOF'
# Source from Bash. Other POSIX shells can set LLVM_ROOT before sourcing.
if [ -n "${BASH_SOURCE:-}" ]; then
    llvm_env_root=$(CDPATH= cd -- "$(dirname -- "$BASH_SOURCE")" && pwd -P) || return 1
else
    llvm_env_root=${LLVM_ROOT:?Set LLVM_ROOT to the extracted toolchain directory}
fi
export PATH="$llvm_env_root/bin:$PATH"
export LD_LIBRARY_PATH="$llvm_env_root/lib:$llvm_env_root/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset llvm_env_root
EOF
cp /work/tools/llvm-env.fish "$prefix/env.fish"
cp /work/tools/llvm-README.txt "$prefix/README.txt"
for component in llvm clang lld clang-tools-extra; do
	cp "$base/src/llvm-project-23.1.1.src/$component/LICENSE.TXT" "$prefix/share/licenses/$component-LICENSE.TXT"
done
cp "$base/src/zlib-1.3.1/LICENSE" "$prefix/share/licenses/zlib-LICENSE"
cp "$base/deps/lib/libz.a" "$prefix/lib/"
cp "$base/deps/include/"{zlib.h,zconf.h} "$prefix/include/"
# Keep the installed LLVM CMake SDK's zlib dependency inside this package.
python3 - "$prefix/lib/cmake/llvm/LLVMConfig.cmake" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
old = '  set(ZLIB_ROOT )'
new = '  set(ZLIB_ROOT "${LLVM_INSTALL_PREFIX}")\n  set(ZLIB_USE_STATIC_LIBS ON)'
if old not in text and new not in text:
    raise SystemExit('Unexpected LLVM zlib configuration')
path.write_text(text.replace(old, new))
PY
cp "$base/obj/llvm/CMakeCache.txt" "$prefix/BUILD-CMAKE-CACHE.txt"
"$prefix/bin/clang" --version >"$prefix/TOOLCHAIN"
(
	cd "$base/sources"
	sha256sum *
) >"$prefix/SOURCES.sha256"
sha256sum /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz /work/dist/modern-linux-x86_64.tar.gz >"$prefix/BUILD-INPUTS.sha256"
if [[ ${1:-} == prepare ]]; then
	exit 0
fi
python3 /work/tools/audit-llvm.py "$prefix" | tee "$prefix/ELF-AUDIT.txt"
(
	cd "$prefix"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS
)
tar czf /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz.part -C "$base/package" opt
mv /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz.part /work/dist/llvm-23.1.1-centos7-x86_64.tar.gz
(
	cd /work/dist
	sha256sum llvm-23.1.1-centos7-x86_64.tar.gz >llvm-23.1.1-centos7-x86_64.tar.gz.sha256
)
