#!/usr/bin/env bash
set -euo pipefail
base=/work/build/llvm
version=23.1.1
prefix=/opt/llvm-$version
mkdir -p "$base"/{sources,src,obj,bootstrap,package/opt}
mkdir -p "$base/package$prefix"
ln -sfn "$base/package$prefix" "$prefix"
for input in gcc-16.2.0-centos7-x86_64 modern-linux-x86_64; do
	if [[ ! -f $base/bootstrap/$input.done ]]; then
		tar xzf "/work/dist/$input.tar.gz" -C "$base/bootstrap"
		touch "$base/bootstrap/$input.done"
	fi
done
ln -sfn "$base/bootstrap/opt/gcc-16.2.0" /opt/gcc-16.2.0
ln -sfn "$base/bootstrap/opt/modern-linux" /opt/modern-linux
. /opt/gcc-16.2.0/env.sh
export PATH="/opt/modern-linux/bin:$PATH"
# Build tools use the container's full development headers; the package
# receives a separate minimal CentOS 7 sysroot when installed.
export CFLAGS='--sysroot=/ -O2 -march=x86-64 -mtune=generic'
export CXXFLAGS="$CFLAGS"
export LDFLAGS='--sysroot=/'
jobs=${JOBS:-10}
fetch() {
	local url=$1 file=$base/sources/$2
	if [[ ! -s $file ]]; then
		curl -fL --retry 5 "$url" -o "$file.part"
		mv "$file.part" "$file"
	fi
}
fetch "https://github.com/llvm/llvm-project/releases/download/llvmorg-$version/llvm-project-$version.src.tar.xz" "llvm-project-$version.src.tar.xz"
fetch https://www.python.org/ftp/python/3.12.10/Python-3.12.10.tar.xz Python-3.12.10.tar.xz
fetch https://github.com/ninja-build/ninja/archive/refs/tags/v1.12.1.tar.gz ninja-1.12.1.tar.gz
fetch https://zlib.net/fossils/zlib-1.3.1.tar.gz zlib-1.3.1.tar.gz
if [[ ! -d $base/src/llvm-project-$version.src ]]; then
	tar xf "$base/sources/llvm-project-$version.src.tar.xz" -C "$base/src"
fi
if [[ ! -x $base/python/bin/python3 ]]; then
	tar xf "$base/sources/Python-3.12.10.tar.xz" -C "$base/src"
	mkdir -p "$base/obj/python"
	cd "$base/obj/python"
	"$base/src/Python-3.12.10/configure" --prefix="$base/python" --without-ensurepip --disable-test-modules
	make -j"$jobs"
	make install
fi
export PATH="$base/python/bin:$PATH"
if [[ ! -x $base/src/ninja-1.12.1/ninja ]]; then
	tar xf "$base/sources/ninja-1.12.1.tar.gz" -C "$base/src"
	cd "$base/src/ninja-1.12.1"
	python3 configure.py --bootstrap
fi
export PATH="$base/src/ninja-1.12.1:$PATH"
if [[ ! -f $base/deps/lib/libz.a ]]; then
	tar xf "$base/sources/zlib-1.3.1.tar.gz" -C "$base/src"
	cd "$base/src/zlib-1.3.1"
	CFLAGS="$CFLAGS -fPIC" ./configure --static --prefix="$base/deps"
	make -j"$jobs"
	make install
fi
cmake -S "$base/src/llvm-project-$version.src/llvm" -B "$base/obj/llvm" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
	-DCMAKE_C_COMPILER=/opt/gcc-16.2.0/bin/gcc -DCMAKE_CXX_COMPILER=/opt/gcc-16.2.0/bin/g++ \
	-DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
	-DCMAKE_EXE_LINKER_FLAGS=-static-libgcc -DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc \
	-DLLVM_ENABLE_PROJECTS='clang;lld;clang-tools-extra' -DLLVM_TARGETS_TO_BUILD=X86 \
	-DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCLANG_LINK_CLANG_DYLIB=ON \
	-DLLVM_STATIC_LINK_CXX_STDLIB=ON -DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_APPEND_VC_REV=OFF \
	-DLLVM_ENABLE_ZLIB=FORCE_ON -DZLIB_LIBRARY="$base/deps/lib/libz.a" \
	-DZLIB_INCLUDE_DIR="$base/deps/include" -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
	-DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_TERMINFO=OFF \
	-DLLVM_ENABLE_LIBPFM=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
	-DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_ENABLE_BINDINGS=OFF \
	-DCLANG_DEFAULT_LINKER=lld -DCLANG_DEFAULT_CXX_STDLIB=libstdc++ \
	-DCLANG_CONFIG_FILE_SYSTEM_DIR= -DCLANG_CONFIG_FILE_USER_DIR= \
	-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib' -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
cmake --build "$base/obj/llvm" -j "$jobs"
cmake --install "$base/obj/llvm" --strip
bash /work/tools/package-llvm.sh prepare
bash /work/tools/build-compiler-rt.sh
bash /work/tools/package-llvm.sh
