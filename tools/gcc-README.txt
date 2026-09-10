GCC 16.2.0 + Binutils 2.47 for CentOS 7 x86_64

Install without sudo (extract the whole package, then source from Bash):
  mkdir -p "$HOME/opt"
  tar xzf gcc-16.2.0-centos7-x86_64.tar.gz -C "$HOME/opt" --strip-components=1
  source "$HOME/opt/gcc-16.2.0/env.sh"
  gcc --version
  g++ -std=c++23 hello.cc -o hello
  ./hello

For fish, source the native fish script instead of env.sh:
  source "$HOME/opt/gcc-16.2.0/env.fish"
You may add this line to ~/.config/fish/config.fish for new shells.

The compiler targets the baseline x86-64 CPU and glibc 2.17. C and C++,
LTO, OpenMP, and static/shared GCC runtime libraries are included.
32-bit multilib, other language frontends, Graphite, zstd LTO compression,
and sanitizers are disabled. Make/CMake/Ninja are separate tools.

The package contains CentOS 7 development headers and linker inputs in
sysroot, so basic C/C++ compilation needs no system gcc, binutils, or
glibc-devel package. The system's /lib64/ld-linux-x86-64.so.2 and glibc
are used to run programs; the bundled sysroot does not replace system
libraries. Additional third-party libraries still need their own headers
and libraries. The sysroot's default header set is specifically CentOS 7.

The directory can be moved; source env.sh (or env.fish for fish) from its
new location afterwards.
GCC and Binutils locate their sysroot relative to their installation.
For non-Bash POSIX shells, set GCC_ROOT to the installation directory
before sourcing "$GCC_ROOT/env.sh".

env.sh sets PATH and LD_LIBRARY_PATH for this shell. Dynamically linked
C++/OpenMP programs need the corresponding libraries from this package
when run elsewhere. For C++ binaries needing no external libstdc++ or
libgcc_s, use:
  g++ -std=c++23 -static-libstdc++ -static-libgcc hello.cc -o hello
This still dynamically uses system glibc. Full static glibc linking is
not supplied by this package. Do not copy these libraries into /usr/lib64
or replace the system GCC.

Build: bash build-gcc.sh
Validate: bash tools/test-gcc.sh
The build uses GCC 9.5.0 as an intermediate compiler in CentOS 7, then
builds GCC 16.2.0 without a three-stage bootstrap comparison. Validation
is a compatibility smoke test, not the complete upstream GCC testsuite.
See build/gcc/container-test.log, build/gcc/unprivileged-test.log, and
build/gcc/kernel-test/serial.log in
the build workspace. kernel-test/PASS binds success to an archive hash.

Official release source: https://gcc.gnu.org/releases.html
SOURCES.sha256 records downloaded archive hashes, not independently
pinned trusted hashes. Prerequisite archives are checked by GCC's own
download_prerequisites script. SYSROOT-RPMS records CentOS inputs;
TOOLCHAIN records configure options; SHA256SUMS checks installed files.
License texts are in share/licenses and GCC's installed documentation.
