LLVM 23.1.1 for CentOS 7 x86_64

Install without sudo; extract the whole package:
  mkdir -p "$HOME/opt"
  tar xzf llvm-23.1.1-centos7-x86_64.tar.gz -C "$HOME/opt" --strip-components=1
  source "$HOME/opt/llvm-23.1.1/env.sh"       # Bash
  source "$HOME/opt/llvm-23.1.1/env.fish"     # fish: use this instead
  clang --version
  clang++ -std=c++23 hello.cc -o hello
  ./hello

Move the whole directory and source the environment script again to relocate.
Other POSIX shells can set LLVM_ROOT before sourcing "$LLVM_ROOT/env.sh".

Includes Clang, LLD, clangd, clang-format, clang-tidy, LLVM utilities,
libraries and development headers. Only the X86 backend is built.
Default C++ library: bundled GCC 16.2.0 libstdc++; default linker: LLD.
CentOS 7 development sysroot and GCC startup/runtime files are included;
the separate GCC package is not required on the target machine.
The system's glibc >= 2.17 and its dynamic loader are still required.

This is a native x86_64 C/C++ toolchain, not a complete build of every LLVM
subproject. LLDB, Flang, MLIR, libc++,
OpenMP and accelerator runtimes are not included. zlib 1.3.1 is statically
linked to support compressed debug information without an extra shared
dependency. Optional zstd, libxml2, curl, libedit and terminfo integrations
are disabled to minimize dependencies. Python helper scripts
require a separately installed Python. Make/CMake/Ninja remain separate.

Clang's adjacent .cfg files locate the bundled sysroot and GCC runtime
relative to the installation. --no-default-config disables these defaults
when intentionally using a different SDK. Extra third-party libraries
still need their own headers and libraries.

env.sh/env.fish set PATH and LD_LIBRARY_PATH for the current shell.
Dynamically linked C++ programs need the bundled libstdc++/libgcc_s when
deployed elsewhere. To link those C++ runtime libraries into a program:
  clang++ -static-libstdc++ -static-libgcc hello.cc -o hello
This still uses system glibc dynamically; full static glibc is not supplied.

Build: bash build-llvm.sh
Requires the repository's GCC 16.2.0 and modern-linux archives as build
inputs, plus Podman and network access. They are not runtime dependencies.
Build caches are in build/llvm. JOBS controls compilation parallelism;
links are serialized to limit peak memory. No upstream full test suite
or bootstrap comparison is claimed. Compatibility smoke tests run in a
clean CentOS 7 container and on its real 3.10 kernel under QEMU.

Official release: https://github.com/llvm/llvm-project/releases/tag/llvmorg-23.1.1
SOURCES.sha256 records downloaded archives, not independently pinned
trusted checksums. BUILD-INPUTS.sha256 records the bootstrap packages.
BUILD-CMAKE-CACHE.txt records build options; ELF-AUDIT.txt records ABI
checks; SHA256SUMS checks installed files. License texts: share/licenses.

compiler-rt 23.1.1 is included for x86_64 in lib/clang/23/lib/linux.
Includes builtins, ASan, UBSan, TSan, LSan, MSan, libFuzzer, profiling,
XRay and other runtimes enabled by upstream's native build configuration.
ASan/UBSan/TSan/LSan fault detection, clean ASan/UBSan/TSan C++ programs,
builtins, libFuzzer and profile/coverage have dedicated smoke tests.
Other runtimes are built but not individually validated on CentOS 7.
MSan requires instrumented application dependencies; the bundled libstdc++
is not MSan-instrumented. Runtime availability alone does not provide a
complete MSan C++ environment.
  clang++ -g -O1 -fsanitize=address -fno-omit-frame-pointer hello.cc -o hello
  ./hello
Default sanitizer linkage uses the included static runtime archives;
system glibc remains dynamic. No separate compiler-rt installation needed.
TSan uses its scalar implementation to support CPUs without SSE4.2.
libFuzzer is patched to remove its forced POPCNT target attribute, allowing
software popcount on baseline x86_64 CPUs.
COMPILER-RT-CMAKE-CACHE.txt records the runtime build configuration.
