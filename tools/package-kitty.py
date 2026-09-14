#!/usr/bin/env python3
"""Collect ordinary runtime libraries while leaving glibc/graphics to the OS."""
import json
import os
import pathlib
import re
import shutil
import subprocess

root = pathlib.Path('/work/build/kitty/package/opt/kitty-0.48.2')
# setup.py can retain the launcher when only linker options change. Relink it
# from its recorded command before deriving the software-rendering variant.
commands = json.loads(pathlib.Path('/work/build/kitty/src/kitty-0.48.2/build/link_commands.json').read_text())
for command in commands:
    args = command['arguments']
    if str(root / 'bin/kitty') in args:
        args[0] = '/work/build/kitty/bootstrap/opt/gcc-16.2.0/bin/gcc'
        subprocess.check_call(args, cwd=command['directory'])
        break
else:
    raise SystemExit('Missing kitty launcher link command')
runtime = root / 'lib/kitty-runtime'
# This directory contains only generated copies from previous packaging runs.
if runtime.exists():
    for old in runtime.iterdir():
        old.unlink()
runtime.mkdir(parents=True, exist_ok=True)
software = root / 'lib/kitty-software'
software.mkdir(parents=True, exist_ok=True)
for name in ('libGL.so.1', 'libglapi.so.0'):
    shutil.copy2(os.path.realpath('/work/build/kitty/mesa/lib/' + name), str(software / name))
shutil.copy2(str(root / 'bin/kitty'), str(root / 'bin/kitty-software'))
subprocess.check_call(['chrpath', '-r', '$ORIGIN/../lib/kitty-software:$ORIGIN/../lib/kitty-runtime', str(root / 'bin/kitty-software')])
system = {'libc.so.6', 'libm.so.6', 'libpthread.so.0', 'libdl.so.2', 'librt.so.1',
          'libutil.so.1', 'libresolv.so.2', 'libnsl.so.1', 'ld-linux-x86-64.so.2',
          'libGL.so.1', 'libEGL.so.1', 'libGLX.so.0', 'libGLdispatch.so.0'}
def elf(path):
    if not path.is_file() or path.is_symlink():
        return False
    with path.open('rb') as f:
        return f.read(4) == b'\x7fELF'
queue = [p for p in root.rglob('*') if elf(p)]
seen = set()
rpm_packages = set()
while queue:
    path = queue.pop()
    if path in seen:
        continue
    seen.add(path)
    proc = subprocess.run(['ldd', str(path)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    if 'not found' in proc.stdout:
        raise SystemExit(proc.stdout)
    needed = set(re.findall(r'\(NEEDED\).*\[(.*?)\]', subprocess.check_output(['readelf', '-dW', str(path)], universal_newlines=True)))
    for name, source in re.findall(r'^\s*(\S+) => (/\S+)', proc.stdout, re.M):
        if name not in needed or name in system or (runtime / name).exists() or (software / name).exists():
            continue
        dest = runtime / name
        owner = subprocess.run(['rpm', '-qf', '--qf', '%{NAME}', os.path.realpath(source)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True)
        if owner.returncode == 0:
            rpm_packages.add(owner.stdout)
        shutil.copy2(os.path.realpath(source), str(dest))
        queue.append(dest)
# Development data are not needed by the embedded Python interpreter.
for path in (root / 'lib/kitty-python').rglob('*.a'):
    path.unlink()
for path in root.rglob('*'):
    if elf(path):
        dynamic = subprocess.check_output(['readelf', '-dW', str(path)], universal_newlines=True)
        if path.parent in (runtime, software) and re.search(r'\((?:RPATH|RUNPATH)\)', dynamic):
            subprocess.check_call(['chrpath', '-d', str(path)])
        subprocess.check_call(['strip', '--strip-unneeded', str(path)])
shutil.copy2('/work/tools/kitty-README.txt', str(root / 'README.txt'))
licenses = root / 'share/licenses'
licenses.mkdir(parents=True, exist_ok=True)
shutil.copy2('/work/build/kitty/src/kitty-0.48.2/LICENSE', str(licenses / 'kitty-LICENSE'))
for component, filename in [('mesa-21.3.9', 'docs/license.rst'), ('openssl-3.5.2', 'LICENSE.txt'), ('xxHash-0.8.3', 'LICENSE'), ('Python-3.12.10', 'LICENSE'), ('freetype-2.13.3', 'docs/FTL.TXT'), ('harfbuzz-8.5.0', 'COPYING'), ('pixman-0.44.2', 'COPYING'), ('cairo-1.18.4', 'COPYING'), ('dbus-1.14.10', 'COPYING'), ('simde-0.8.2', 'COPYING'), ('libxkbcommon-xkbcommon-1.8.1', 'LICENSE')]:
    shutil.copy2('/work/build/kitty/src/' + component + '/' + filename, str(licenses / (component + '-LICENSE')))
shutil.copy2('/work/build/kitty/sources/nerd-fonts-LICENSE', str(licenses / 'nerd-fonts-LICENSE'))
# Preserve redistribution notices for bundled CentOS libraries.
for source in pathlib.Path('/usr/share/licenses').iterdir():
    if source.is_dir():
        shutil.copytree(str(source), str(licenses / source.name), dirs_exist_ok=True)

recipes = root / 'share/build'
recipes.mkdir(parents=True, exist_ok=True)
for name in ('build-kitty-inside.sh', 'build-kitty-mesa.sh', 'kitty-centos7-compat.h', 'Containerfile.kitty'):
    shutil.copy2('/work/tools/' + name, str(recipes / name))

# Keep the actual GCC runtime exception and notices, plus complete source and
# RPM license files (some CentOS packages use share/doc, not share/licenses).
shutil.copytree('/work/build/kitty/bootstrap/opt/gcc-16.2.0/share/licenses', str(licenses / 'gcc-runtime'), dirs_exist_ok=True)
for source in pathlib.Path('/work/build/kitty/src/cairo-1.18.4').glob('COPYING*'):
    shutil.copy2(str(source), str(licenses / ('cairo-' + source.name)))
for package in sorted(rpm_packages):
    files = subprocess.check_output(['rpm', '-ql', package], universal_newlines=True).splitlines()
    for filename in files:
        source = pathlib.Path(filename)
        if source.is_file() and re.search(r'(^|/)(copying[^/]*|licen[cs]e[^/]*|copyright[^/]*)(/|$)', filename, re.I):
            dest = licenses / 'rpm' / package / filename.lstrip('/')
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(source), str(dest))
