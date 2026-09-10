#!/bin/sh
set -eu
LLVM_ROOT=${LLVM_ROOT:-/opt/llvm-23.1.1}
. "$LLVM_ROOT/env.sh"
mkdir -p /tmp/llvm-smoke
cd /tmp/llvm-smoke
clang --version
clang++ --version
ld.lld --version
test "$(llvm-config --version)" = 23.1.1
cat >hello.c <<'EOF'
#include <stdio.h>
#include <stdatomic.h>
int main(void) { atomic_int x=41; printf("C: %d\n", ++x); return x!=42; }
EOF
clang -std=c23 -O2 -Wall -Werror hello.c -o hello-c
./hello-c
clang -std=c23 -O2 -fPIE -pie hello.c -o hello-pie
./hello-pie
clang -g -gz=zlib hello.c -o hello-zlib
./hello-zlib
llvm-dwarfdump --verify hello-zlib
cat >hello.cc <<'EOF'
#include <atomic>
#include <iostream>
#include <ranges>
#include <stdexcept>
#include <thread>
#include <vector>
int main() {
  std::vector<int> v{1,2,3,4};
  auto r=v | std::views::transform([](int x){return x*x;});
  std::atomic<int> sum{0};
  std::thread t([&]{for (int x:r) sum+=x;}); t.join();
  try { throw std::runtime_error("exception OK"); }
  catch(const std::exception& e) {std::cout<<e.what()<<'\n';}
  std::cout<<"C++: "<<sum<<'\n'; return sum!=30;
}
EOF
clang++ -std=c++23 -O2 -pthread -Wall -Werror hello.cc -o hello-cxx
./hello-cxx
clang++ -std=c++23 -O2 -pthread -flto=thin hello.cc -o hello-thinlto
./hello-thinlto
clang++ -std=c++23 -O2 -pthread -flto=full hello.cc -o hello-lto
./hello-lto
clang++ -std=c++23 -O2 -pthread -static-libstdc++ -static-libgcc hello.cc -o hello-static-runtime
env -u LD_LIBRARY_PATH ./hello-static-runtime
echo 'int answer(void) {return 42;}' >shared.c
echo 'extern int answer(void); int main(void) {return answer()!=42;}' >main.c
clang -O2 -fPIC -shared shared.c -o libanswer.so
clang main.c -L. -lanswer -Wl,-rpath,'$ORIGIN' -o hello-shared
./hello-shared
clang -O2 -flto=thin -c shared.c -o archive.o
llvm-ar rcs libanswer.a archive.o
llvm-ranlib libanswer.a
clang -flto=thin main.c ./libanswer.a -o hello-archive
./hello-archive
echo 'int main(void) {return 0;}' >jit.c
clang -O1 -emit-llvm -c jit.c -o jit.bc
opt -passes='default<O2>' jit.bc -o optimized.bc
lli optimized.bc
llc -filetype=obj optimized.bc -o jit.o
clang jit.o -o hello-ir
./hello-ir
llvm-dis optimized.bc -o optimized.ll
llvm-as optimized.ll -o roundtrip.bc
llvm-nm hello-c | grep -q main
llvm-objdump -d hello-c >disassembly.txt
clang-format hello.cc >formatted.cc
clang++ -std=c++23 -pthread formatted.cc -o hello-formatted
./hello-formatted
echo 'int bug(void) {int *p=0; return *p;}' >tidy.c
clang-tidy --checks='-*,clang-analyzer-core.NullDereference' tidy.c -- -std=c17 >tidy.log 2>&1
grep -q 'clang-analyzer-core.NullDereference' tidy.log
cat >compile_commands.json <<EOF
[{"directory":"/tmp/llvm-smoke","file":"hello.cc","arguments":["$LLVM_ROOT/bin/clang++","-std=c++23","-pthread","-c","hello.cc"]}]
EOF
if ! clangd --check=hello.cc --query-driver="$LLVM_ROOT/bin/clang++" \
    --compile-commands-dir=/tmp/llvm-smoke >clangd.log 2>&1; then
    cat clangd.log
    exit 1
fi
cat >llvm-api.cc <<'EOF'
#include <llvm-c/Core.h>
int main() {auto c=LLVMContextCreate(); LLVMContextDispose(c); return 0;}
EOF
clang++ llvm-api.cc $(llvm-config --cxxflags --ldflags --link-shared --libs core) -o hello-llvm-api
./hello-llvm-api
clang++ llvm-api.cc $(llvm-config --cxxflags --ldflags --link-static --libs core --system-libs) -o hello-llvm-static-api
./hello-llvm-static-api
echo LLVM_SMOKE_PASS
