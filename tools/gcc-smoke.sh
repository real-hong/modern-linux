#!/bin/sh
set -eu
GCC_ROOT=${GCC_ROOT:-/opt/gcc-16.2.0}
. "$GCC_ROOT/env.sh"
mkdir -p /tmp/gcc-smoke
cd /tmp/gcc-smoke
gcc --version
g++ --version
ld --version
test "$(gcc -dumpfullversion)" = 16.2.0
cat >hello.c <<'EOF'
#include <stdio.h>
#include <stdatomic.h>
int main(void) { atomic_int x = 41; printf("C: %d\n", ++x); return x != 42; }
EOF
gcc -std=c23 -O2 -Wall -Werror hello.c -o hello-c
./hello-c
gcc -std=c23 -O2 -fPIE -pie hello.c -o hello-pie
./hello-pie
cat >hello.cc <<'EOF'
#include <algorithm>
#include <atomic>
#include <iostream>
#include <numeric>
#include <ranges>
#include <stdexcept>
#include <thread>
#include <vector>
int main() {
  std::vector<int> v{1,2,3,4};
  auto r = v | std::views::transform([](int x) { return x*x; });
  std::atomic<int> sum{0};
  std::thread t([&] { for (int x : r) sum += x; }); t.join();
  try { throw std::runtime_error("exception OK"); }
  catch (const std::exception& e) { std::cout << e.what() << '\n'; }
  std::cout << "C++: " << sum << '\n';
  return sum != 30;
}
EOF
g++ -std=c++23 -O2 -pthread -Wall -Werror hello.cc -o hello-cxx
./hello-cxx
g++ -std=c++23 -O2 -flto -pthread hello.cc -o hello-lto
./hello-lto
g++ -std=c++23 -O2 -pthread -static-libstdc++ -static-libgcc hello.cc -o hello-static-runtime
env -u LD_LIBRARY_PATH ./hello-static-runtime
cat >omp.c <<'EOF'
#include <stdio.h>
int main(void) {
  int sum=0;
  #pragma omp parallel for reduction(+:sum)
  for (int i=0;i<100;i++) sum+=i;
  printf("OpenMP: %d\n",sum);
  return sum!=4950;
}
EOF
gcc -O2 -fopenmp omp.c -o hello-omp
OMP_NUM_THREADS=2 ./hello-omp
echo 'int answer(void) { return 42; }' >shared.c
echo 'extern int answer(void); int main(void) { return answer()!=42; }' >main.c
gcc -O2 -fPIC -shared shared.c -o libanswer.so
gcc main.c -L. -lanswer -Wl,-rpath,'$ORIGIN' -o hello-shared
./hello-shared
gcc -O2 -flto -c shared.c -o archive.o
gcc-ar rcs libanswer.a archive.o
gcc-ranlib libanswer.a
gcc -O2 -flto main.c ./libanswer.a -o hello-archive
./hello-archive
echo GCC_SMOKE_PASS
