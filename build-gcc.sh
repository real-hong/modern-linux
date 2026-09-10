#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
engine=${ENGINE:-podman}
case ${1:-all} in all | build | test) mode=${1:-all} ;; *)
	echo 'Usage: bash build-gcc.sh [all|build|test]' >&2
	exit 2
	;;
esac
mkdir -p build/gcc dist
if [[ $mode != test ]]; then
	"$engine" build --network=host -t localhost/modern-linux-gcc-builder -f tools/Containerfile.gcc .
	"$engine" run --rm --network=host --security-opt label=disable \
		-e JOBS="${JOBS:-12}" -v "$PWD:/work" localhost/modern-linux-gcc-builder \
		bash /work/tools/build-gcc-inside.sh
fi
if [[ $mode != build ]]; then
	ENGINE="$engine" bash tools/test-gcc.sh
fi
