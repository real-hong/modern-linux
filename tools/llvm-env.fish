# Source this file from fish after extracting the whole toolchain.
set -l llvm_env_root (command dirname (status filename))
set llvm_env_root (command realpath -- "$llvm_env_root")
or return 1
set -gx PATH "$llvm_env_root/bin" $PATH
set -gx LD_LIBRARY_PATH "$llvm_env_root/lib" "$llvm_env_root/lib64" $LD_LIBRARY_PATH
