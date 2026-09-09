#!/usr/bin/env bash
set -euo pipefail
root=${1:?Usage: audit-static.sh package-root}
[[ -d $root/bin ]] || exit 1
export LC_ALL=C
while IFS= read -r -d '' binary; do
    relative=${binary#"$root"/}
    preload=false
    case "$relative" in
    libexec/valgrind/vgpreload_core-amd64-linux.so | \
        libexec/valgrind/vgpreload_memcheck-amd64-linux.so | \
        libexec/valgrind/vgpreload_helgrind-amd64-linux.so | \
        libexec/valgrind/vgpreload_drd-amd64-linux.so | \
        libexec/valgrind/vgpreload_massif-amd64-linux.so | \
        libexec/valgrind/vgpreload_dhat-amd64-linux.so)
        preload=true
        ;;
    *.so | *.so.*)
        echo "Unexpected shared module: $relative" >&2
        exit 1
        ;;
    esac
    magic=
    IFS= read -r -N 4 magic <"$binary" || true
    if [[ $magic != $'\177ELF' ]]; then
        if $preload; then
            echo "Not an ELF preload module: $relative" >&2
            exit 1
        fi
        if [[ $relative == bin/* && $magic != '#!'* ]]; then
            echo "Not an ELF executable or script: $relative" >&2
            exit 1
        fi
        continue
    fi
    headers=$(readelf -hW "$binary")
    program=$(readelf -lW "$binary")
    dynamic=$(readelf -dW "$binary")
    if [[ $program == *INTERP* || $dynamic == *'(NEEDED)'* ]]; then
        echo "Dynamic dependency detected: $relative" >&2
        exit 1
    fi
    if $preload; then
        [[ $headers == *'DYN (Shared object file)'* ]] || exit 1
        # These modules resolve symbols in the glibc target process. They
        # must not introduce DT_NEEDED dependencies of their own.
    elif [[ $headers == *'DYN (Shared object file)'* ]]; then
        echo "Dynamic dependency detected: $relative" >&2
        exit 1
    fi
done < <(find "$root" -type f -print0)
