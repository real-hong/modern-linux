#!/bin/sh
set -eu
LLVM_ROOT=${LLVM_ROOT:-/opt/llvm-23.1.1}
export LLVM_ROOT
. "$LLVM_ROOT/env.sh"
mkdir -p /tmp/compiler-rt-smoke
cd /tmp/compiler-rt-smoke
cat > clean.cc <<'SRC'
#include <thread>
#include <cstdlib>
int main() { int x = 0; std::thread t([&]{x=42;}); t.join(); return x != 42; }
SRC
for san in address undefined thread; do
    echo "Testing sanitizer: $san"
    clang++ -O1 -g -fsanitize="$san" -fno-omit-frame-pointer clean.cc -pthread -o clean
    ./clean
done
expect_report() {
    if "$1" >report.log 2>&1; then
        echo "Expected sanitizer failure: $1"; exit 1
    fi
    cat report.log
    grep -q "$2" report.log
}
cat > address.c <<'SRC'
#include <stdlib.h>
int main(int argc, char **argv) { volatile char *p = malloc(4); p[argc+7]=1; free((void*)p); return 0; }
SRC
clang -O1 -g -fsanitize=address -fno-omit-frame-pointer address.c -o address
expect_report ./address 'AddressSanitizer: heap-buffer-overflow'
cat > undefined.c <<'SRC'
#include <limits.h>
int main() { volatile int x=INT_MAX; return x+1; }
SRC
clang -O1 -g -fsanitize=undefined -fno-sanitize-recover=all undefined.c -o undefined
expect_report ./undefined 'signed integer overflow'
cat > thread.cc <<'SRC'
#include <thread>
volatile int value;
int main() { std::thread a([]{for(int i=0;i<10000;++i) value=1;}); for(int i=0;i<10000;++i) value=2; a.join(); }
SRC
clang++ -O1 -g -fsanitize=thread thread.cc -pthread -o thread
expect_report ./thread 'ThreadSanitizer: data race'
cat > leak.c <<'SRC'
#include <stdlib.h>
__attribute__((noinline)) void leak(void) { void *p=malloc(123); __asm__ volatile("" : : "r"(p) : "memory"); }
int main() { leak(); return 0; }
SRC
clang -O1 -g -fsanitize=leak leak.c -o leak
expect_report ./leak 'LeakSanitizer: detected memory leaks'
cat > builtins.c <<'SRC'
volatile __int128 a = ((__int128)1 << 100), b=7;
int main() { return a/b != (((__int128)1 << 100)/7); }
SRC
clang --rtlib=compiler-rt builtins.c -o builtins
./builtins
cat > fuzz.c <<'SRC'
#include <stddef.h>
#include <stdint.h>
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) { return size && data[0] == 42; }
SRC
clang -g -fsanitize=fuzzer,address fuzz.c -o fuzz
./fuzz -runs=100
clang -fprofile-instr-generate -fcoverage-mapping builtins.c -o profile
LLVM_PROFILE_FILE=sample.profraw ./profile
llvm-profdata merge sample.profraw -o sample.profdata
llvm-cov report ./profile -instr-profile=sample.profdata
echo COMPILER_RT_SMOKE_PASS
