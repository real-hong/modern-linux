#!/usr/bin/env python3
"""Audit every installed ELF for CentOS 7 ABI and self-contained dependencies."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
system = {'libc.so.6', 'libm.so.6', 'libpthread.so.0', 'libdl.so.2',
          'librt.so.1', 'libutil.so.1', 'libresolv.so.2', 'ld-linux-x86-64.so.2'}
count = 0
dependencies = set()
for path in sorted(root.rglob('*')):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open('rb') as stream:
        if stream.read(4) != b'\x7fELF':
            continue
    count += 1
    output = subprocess.check_output(['readelf', '-W', '-h', '-l', '-d', '-V', str(path)], universal_newlines=True)
    if 'Advanced Micro Devices X86-64' not in output:
        raise SystemExit('Unexpected architecture: ' + str(path))
    needed = set(re.findall(r'\(NEEDED\).*\[(.*?)\]', output))
    dependencies.update(needed)
    for name in needed - system:
        if not any((root / directory / name).is_file() and
                   root in (root / directory / name).resolve().parents
                   for directory in ('lib', 'lib64')):
            raise SystemExit('Unbundled dependency: {}: {}'.format(path, name))
    needs = output.split('Version needs section', 1)[-1] if 'Version needs section' in output else ''
    for version in re.findall(r'Name: GLIBC_([\d.]+)', needs):
        if tuple(map(int, version.split('.'))) > (2, 17):
            raise SystemExit('New glibc requirement: {}: {}'.format(path, version))
    for loader in re.findall(r'Requesting program interpreter: (.*?)\]', output):
        if loader != '/lib64/ld-linux-x86-64.so.2':
            raise SystemExit('Unexpected loader: ' + loader)
    for search in re.findall(r'\((?:RPATH|RUNPATH)\).*\[(.*?)\]', output):
        if any(not entry.startswith('$ORIGIN') for entry in search.split(':')):
            raise SystemExit('Non-relative runtime search path: {}: {}'.format(path, search))
if not count:
    raise SystemExit('No ELF files found')
print('PASS: {} ELF files; required GLIBC versions <= 2.17'.format(count))
print('DT_NEEDED: ' + ', '.join(sorted(dependencies)))
