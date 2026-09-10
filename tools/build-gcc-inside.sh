#!/usr/bin/env bash
set -euo pipefail
base=/work/build/gcc
prefix=/opt/gcc-16.2.0
mkdir -p "$base"/{sources,src,obj,package/opt}
mkdir -p "$base/package$prefix"
ln -sfn "$base/package$prefix" "$prefix"
jobs=${JOBS:-12}
export CONFIG_SHELL=/bin/bash
export CFLAGS='-O2 -march=x86-64 -mtune=generic'
export CXXFLAGS="$CFLAGS"
fetch() {
	local url=$1 file=$base/sources/${1##*/}
	if [[ ! -s $file ]]; then
		curl -fL --retry 5 "$url" -o "$file.part"
		mv "$file.part" "$file"
	fi
}
source_tree() {
	local name=$1
	if [[ ! -d $base/src/$name ]]; then
		tar xf "$base/sources/$name.tar.xz" -C "$base/src"
	fi
}
for version in 9.5.0 16.2.0; do
	fetch "https://gcc.gnu.org/pub/gcc/releases/gcc-$version/gcc-$version.tar.xz"
	source_tree gcc-$version
	(
		cd "$base/src/gcc-$version"
		# Upstream script verifies the prerequisite archives against its checksums.
		if [[ ! -d gmp ]]; then
			sed 's|http://gcc.gnu.org/|https://gcc.gnu.org/|g' contrib/download_prerequisites >download-prerequisites-https
			bash download-prerequisites-https --no-isl
		fi
	)
done
fetch https://ftp.gnu.org/gnu/binutils/binutils-2.47.tar.xz
source_tree binutils-2.47
if [[ ! -f $base/bootstrap/bin/g++ ]]; then
	mkdir -p "$base/obj/bootstrap"
	cd "$base/obj/bootstrap"
	"$base/src/gcc-9.5.0/configure" --prefix="$base/bootstrap" \
		--enable-languages=c,c++ --disable-multilib --disable-bootstrap \
		--disable-nls --disable-libsanitizer --disable-libquadmath --disable-libgomp \
		--without-isl --without-zstd
	make -j"$jobs"
	make install-strip
fi
export PATH="$base/bootstrap/bin:$PATH"
export LD_LIBRARY_PATH="$base/bootstrap/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [[ ! -f $base/binutils.done ]]; then
	mkdir -p "$base/obj/binutils"
	cd "$base/obj/binutils"
	"$base/src/binutils-2.47/configure" --prefix="$prefix" --disable-nls \
		--disable-werror --disable-gdb --disable-gdbserver --disable-gprofng \
		--disable-sim --disable-shared --enable-static --without-debuginfod \
		--without-zstd --with-sysroot="$prefix/sysroot" \
		LDFLAGS='-static-libstdc++ -static-libgcc'
	make -j"$jobs"
	make install-strip
	touch "$base/binutils.done"
fi
mkdir -p "$prefix/sysroot"/{usr/lib,usr/lib64,lib,lib64}
cp -a /usr/lib64/*crt*.o "$prefix/sysroot/usr/lib64/"
if [[ ! -d $prefix/sysroot/usr/include ]]; then
	while IFS= read -r file; do
		if [[ $file == /usr/include/* && (-f $file || -L $file) ]]; then
			cp -a --parents "$file" "$prefix/sysroot/"
		fi
	done < <(rpm -ql glibc-devel glibc-headers kernel-headers)
	for file in /usr/lib64/crt*.o /usr/lib64/lib{c,m,pthread,dl,rt,util,resolv}.so /usr/lib64/*nonshared.a; do
		cp -a "$file" "$prefix/sysroot/usr/lib64/"
	done
	for file in /lib64/lib{c,m,pthread,dl,rt,util,resolv}.so.* /lib64/ld-linux-x86-64.so.2; do
		cp -L "$file" "$prefix/sysroot/lib64/"
	done
fi
export PATH="$prefix/bin:$PATH"
if [[ ! -f $base/gcc.done ]]; then
	mkdir -p "$base/obj/gcc"
	cd "$base/obj/gcc"
	"$base/src/gcc-16.2.0/configure" --prefix="$prefix" \
		--enable-languages=c,c++ --disable-multilib --disable-bootstrap \
		--disable-nls --without-isl --without-zstd --disable-libsanitizer \
		--with-sysroot="$prefix/sysroot" --with-native-system-header-dir=/usr/include \
		--with-arch=x86-64 --with-tune=generic \
		--with-static-standard-libraries --disable-libstdcxx-pch
	make -j"$jobs"
	make install-strip
	touch "$base/gcc.done"
fi
cat >"$prefix/env.sh" <<'EOF'
# Source from Bash. Other POSIX shells can set GCC_ROOT before sourcing.
if [ -n "${BASH_SOURCE:-}" ]; then
    gcc_env_root=$(CDPATH= cd -- "$(dirname -- "$BASH_SOURCE")" && pwd -P) || return 1
else
    gcc_env_root=${GCC_ROOT:?Set GCC_ROOT to the extracted toolchain directory}
fi
export PATH="$gcc_env_root/bin:$PATH"
export LD_LIBRARY_PATH="$gcc_env_root/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset gcc_env_root
EOF
cp /work/tools/gcc-env.fish "$prefix/env.fish"
# libcc1's libtool embeds the bootstrap compiler's library directory.
# env.sh supplies the relocated runtime directory instead.
for plugin in "$prefix"/lib64/libcc1.so.0.0.0 "$prefix"/lib/gcc/*/16.2.0/plugin/lib{cc,cp}1plugin.so.0.0.0; do
	chrpath -d "$plugin"
done
mkdir -p "$prefix/share/licenses"
cp "$base/src/gcc-16.2.0/"COPYING* "$prefix/share/licenses/"
for license in LICENSES COPYING COPYING.LIB; do
	if [[ ! -s $base/sources/glibc-2.17-$license ]]; then
		curl -fL --retry 5 "https://raw.githubusercontent.com/bminor/glibc/glibc-2.17/$license" -o "$base/sources/glibc-2.17-$license"
	fi
	cp "$base/sources/glibc-2.17-$license" "$prefix/share/licenses/glibc-$license"
done
for component in gmp mpfr mpc; do
	mkdir -p "$prefix/share/licenses/$component"
	cp "$base/src/gcc-16.2.0/$component/"COPYING* "$prefix/share/licenses/$component/"
done
cp "$base/src/gcc-16.2.0/zlib/LICENSE" "$prefix/share/licenses/zlib-LICENSE"
cp /work/tools/gcc-README.txt "$prefix/README.txt"
rpm -q glibc glibc-devel glibc-headers kernel-headers >"$prefix/SYSROOT-RPMS"
"$prefix/bin/gcc" -v >"$prefix/TOOLCHAIN" 2>&1
(
	cd "$base/sources"
	sha256sum *.tar.xz
) >"$prefix/SOURCES.sha256"
for version in 9.5.0 16.2.0; do
	(
		cd "$base/src/gcc-$version"
		find . -maxdepth 1 -type f -name '*.tar.*' -exec sha256sum {} +
	) >>"$prefix/SOURCES.sha256"
done
python3 /work/tools/audit-gcc.py "$prefix" | tee "$prefix/ELF-AUDIT.txt"
(
	cd "$prefix"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS
)
tar czf /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz.part -C "$base/package" opt
mv /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz.part /work/dist/gcc-16.2.0-centos7-x86_64.tar.gz
(cd /work/dist; sha256sum gcc-16.2.0-centos7-x86_64.tar.gz >gcc-16.2.0-centos7-x86_64.tar.gz.sha256)
