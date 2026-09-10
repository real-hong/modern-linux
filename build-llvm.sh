#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
engine=${ENGINE:-podman}
case ${1:-all} in all | build | test) mode=${1:-all} ;; *)
	echo 'Usage: bash build-llvm.sh [all|build|test]' >&2
	exit 2
	;;
esac
mkdir -p build/llvm dist
if [[ $mode != test ]]; then
	for input in gcc-16.2.0-centos7-x86_64 modern-linux-x86_64; do
		test -f "dist/$input.tar.gz" || {
			echo "Missing build input: dist/$input.tar.gz" >&2
			exit 1
		}
	done
	"$engine" build --network=host -t localhost/modern-linux-gcc-builder -f tools/Containerfile.gcc .
	"$engine" run --rm --network=host --security-opt label=disable \
		-e JOBS="${JOBS:-10}" -v "$PWD:/work" localhost/modern-linux-gcc-builder \
		bash /work/tools/build-llvm-inside.sh
fi
if [[ $mode != build ]]; then
	ENGINE="$engine" bash tools/test-llvm.sh
fi
