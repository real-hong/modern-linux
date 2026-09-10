set -l llvm_root $argv[1]
set -gx LD_LIBRARY_PATH /tmp/llvm-existing-library-path
source "$llvm_root/env.fish"
or exit 1
test "$LD_LIBRARY_PATH[3]" = /tmp/llvm-existing-library-path
or exit 2
test (command -s clang++) = "$llvm_root/bin/clang++"
or exit 3
printf '%s\n' '#include <iostream>' 'int main(){std::cout << "LLVM_FISH_PASS\n";}' > /tmp/llvm-fish.cc
clang++ -std=c++23 /tmp/llvm-fish.cc -o /tmp/llvm-fish
or exit 4
/tmp/llvm-fish
or exit 5
