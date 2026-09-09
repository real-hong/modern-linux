#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
root=$temporary/package
mkdir -p "$root/bin" "$root/libexec/valgrind"
printf 'void _start(void) { for (;;) {} }\n' >"$temporary/static.c"
cc -nostdlib -static "$temporary/static.c" -o "$root/bin/static"
printf '#!/bin/sh\nexit 0\n' >"$root/bin/script"
bash tools/audit-static.sh "$root"

reject() {
    if bash tools/audit-static.sh "$root" >"$temporary/output" 2>&1; then
        echo "Audit incorrectly accepted: $1" >&2
        exit 1
    fi
}
printf 'int main(void) { return 0; }\n' >"$temporary/main.c"
cc "$temporary/main.c" -o "$root/libexec/dynamic-helper"
reject 'a dynamic helper outside bin'
rm "$root/libexec/dynamic-helper"
printf 'not an executable\n' >"$root/bin/broken"
reject 'a malformed binary'
rm "$root/bin/broken"

cc -shared -nostdlib "$temporary/static.c" -o "$root/unknown.so"
reject 'an unlisted shared module'
mv "$root/unknown.so" "$root/libexec/valgrind/vgpreload_core-amd64-linux.so"
bash tools/audit-static.sh "$root"

cc -shared -nostdlib -Wl,-soname,libunexpected.so "$temporary/static.c" -o "$temporary/libunexpected.so"
cc -shared -nostdlib -Wl,--no-as-needed "$temporary/libunexpected.so" \
    -o "$root/libexec/valgrind/vgpreload_core-amd64-linux.so"
reject 'an unapproved preload dependency'
echo 'Static audit regression checks passed.'
