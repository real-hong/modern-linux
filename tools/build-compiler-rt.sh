#!/usr/bin/env bash
set -euo pipefail
base=/work/build/llvm
prefix=/opt/llvm-23.1.1
mkdir -p /opt
ln -sfn "$base/package$prefix" "$prefix"
ln -sfn "$base/bootstrap/opt/gcc-16.2.0" /opt/gcc-16.2.0
ln -sfn "$base/bootstrap/opt/modern-linux" /opt/modern-linux
. "$prefix/env.sh"
export PATH="$base/python/bin:$base/src/ninja-1.12.1:/opt/modern-linux/bin:$PATH"
unset CFLAGS CXXFLAGS LDFLAGS
# libFuzzer otherwise forces POPCNT even with -march=x86-64.
python3 - "$base/src/llvm-project-23.1.1.src/compiler-rt/lib/fuzzer/FuzzerPlatform.h" <<'PYFIX'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
old = '#define ATTRIBUTE_TARGET_POPCNT __attribute__((target("popcnt")))'
new = '#define ATTRIBUTE_TARGET_POPCNT /* baseline x86_64: software popcount */'
if old not in text and new not in text:
    raise SystemExit('Unexpected libFuzzer POPCNT definition')
path.write_text(text.replace(old, new))
PYFIX
# Upstream TSan enables SSE4.2 when the compiler accepts it. Keep the
# scalar implementation so the package also works on baseline x86_64.
cmake -S "$base/src/llvm-project-23.1.1.src/compiler-rt" -B "$base/obj/compiler-rt" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix/lib/clang/23" \
    -DCMAKE_C_COMPILER="$prefix/bin/clang" -DCMAKE_CXX_COMPILER="$prefix/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$prefix/bin/clang" \
    -DCMAKE_C_COMPILER_TARGET=x86_64-unknown-linux-gnu \
    -DCMAKE_CXX_COMPILER_TARGET=x86_64-unknown-linux-gnu \
    -DCMAKE_C_FLAGS='--sysroot=/ -O2 -march=x86-64 -mtune=generic' \
    -DCMAKE_CXX_FLAGS='--sysroot=/ -O2 -march=x86-64 -mtune=generic' \
    -DCMAKE_ASM_FLAGS='--sysroot=/ -march=x86-64' \
    -DLLVM_CMAKE_DIR="$prefix/lib/cmake/llvm" \
    -DCOMPILER_RT_HAS_MSSE4_2_FLAG=OFF \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON -DCOMPILER_RT_INCLUDE_TESTS=OFF \
    -DCOMPILER_RT_USE_LIBCXX=OFF -DCOMPILER_RT_BUILD_BUILTINS=ON \
    -DCOMPILER_RT_BUILD_SANITIZERS=ON -DCOMPILER_RT_SANITIZERS_TO_BUILD=all \
    -DCOMPILER_RT_BUILD_LIBFUZZER=ON -DCOMPILER_RT_BUILD_PROFILE=ON \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../../../../../lib64' -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
cmake --build "$base/obj/compiler-rt" -j "${JOBS:-10}"
cmake --install "$base/obj/compiler-rt"
cp "$base/obj/compiler-rt/CMakeCache.txt" "$prefix/COMPILER-RT-CMAKE-CACHE.txt"
cp "$base/src/llvm-project-23.1.1.src/compiler-rt/LICENSE.TXT" "$prefix/share/licenses/compiler-rt-LICENSE.TXT"
