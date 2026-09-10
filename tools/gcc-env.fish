# Source this file from fish after extracting the whole toolchain.
set -l gcc_env_root (command dirname (status filename))
set gcc_env_root (command realpath -- "$gcc_env_root")
or return 1
set -gx PATH "$gcc_env_root/bin" $PATH
set -gx LD_LIBRARY_PATH "$gcc_env_root/lib64" $LD_LIBRARY_PATH
