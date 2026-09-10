#!/usr/bin/env bash
set -euo pipefail
: "${LLVM_ROOT:?Set LLVM_ROOT}"
. "$LLVM_ROOT/env.sh"
mkdir -p /tmp/llvm-cmake-smoke
cd /tmp/llvm-cmake-smoke
cat >main.cpp <<'EOF'
#include <llvm-c/Core.h>
int main() {auto c=LLVMContextCreate(); LLVMContextDispose(c); return 0;}
EOF
cat >CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.31)
project(llvm_sdk_smoke LANGUAGES C CXX)
find_package(LLVM CONFIG REQUIRED)
foreach(mode shared static)
  add_executable(api-${mode} main.cpp)
  target_include_directories(api-${mode} PRIVATE ${LLVM_INCLUDE_DIRS})
endforeach()
target_link_libraries(api-shared PRIVATE LLVM)
target_link_libraries(api-static PRIVATE LLVMCore)
EOF
cmake=/work/build/llvm/bootstrap/opt/modern-linux/bin/cmake
"$cmake" -S . -B build -G Ninja \
	-DCMAKE_MAKE_PROGRAM=/work/build/llvm/src/ninja-1.12.1/ninja \
	-DCMAKE_C_COMPILER="$LLVM_ROOT/bin/clang" \
	-DCMAKE_CXX_COMPILER="$LLVM_ROOT/bin/clang++" \
	-DLLVM_DIR="$LLVM_ROOT/lib/cmake/llvm"
"$cmake" --build build
build/api-shared
build/api-static
echo LLVM_CMAKE_SDK_PASS
