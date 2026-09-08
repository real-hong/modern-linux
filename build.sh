#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
engine=${ENGINE:-podman}
case ${1:-all} in all | build | test) mode=${1:-all} ;; *)
    echo 'Usage: ./build.sh [all|build|test]' >&2
    exit 2
    ;;
esac
[[ $(uname -m) == x86_64 ]] || {
    echo 'Only x86_64 is supported' >&2
    exit 1
}
mkdir -p build dist
if [[ $mode != test ]]; then
    "$engine" build --network=host -t localhost/modern-linux-builder -f tools/Containerfile .
    "$engine" run --rm --network=host --security-opt label=disable \
        -e JOBS="${JOBS:-4}" -v "$PWD:/work" localhost/modern-linux-builder bash /work/tools/build-inside.sh
fi
if [[ $mode != build ]]; then
    ENGINE="$engine" bash tools/test-kernel.sh
fi
