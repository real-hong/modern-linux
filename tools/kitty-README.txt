kitty 0.48.2 for CentOS 7 x86_64

Extract the entire package anywhere, without sudo:
  mkdir -p "$HOME/opt"
  tar xzf kitty-0.48.2-centos7-x86_64.tar.gz -C "$HOME/opt" --strip-components=1
  "$HOME/opt/kitty-0.48.2/bin/kitty"
Optionally add its bin directory to PATH in your shell configuration.
No env.sh or LD_LIBRARY_PATH setup is required.

Includes kitty, the standalone kitten, Python 3.12 and required ordinary
shared libraries. Uses the system glibc >= 2.17, X11 desktop and installed
fonts/fontconfig configuration. bin/kitty uses the system OpenGL driver,
which must support OpenGL 3.1. If that is unavailable, run bin/kitty-software:
it uses the included Mesa 21.3.9 CPU renderer, with lower performance.
Neither launcher changes LD_LIBRARY_PATH for child programs. This is an X11 build; Wayland
is not included. Hardware GPU drivers and system glibc are not bundled.
The package can be moved as a whole. Do not copy just bin/kitty.

The embedded Python is for kitty; it is not a general Python installation.
SSH and other optional external commands still come from the target system.
Terminfo and shell integration data are included under share and lib/kitty.

Build: bash build-kitty.sh
Build input: the repository's GCC package; target users do not need GCC.
Validation: bash tools/test-kitty.sh
Logs and caches: build/kitty. Full upstream test coverage is not claimed.
ELF-AUDIT.txt records ABI/dependency checks. SHA256SUMS checks installed files.
Licenses are in share/licenses. SOURCES.sha256 records source archives.
Official release: https://github.com/kovidgoyal/kitty/releases/tag/v0.48.2

CentOS 7 adaptations: a checked reallocarray fallback and a volatile-write
explicit_bzero fallback are used where glibc 2.17 lacks these APIs.
Newer FreeType, HarfBuzz, libxkbcommon and D-Bus client libraries are bundled.
Build recipes and the compatibility header are included in share/build.
Source checksums record downloads, not independently authenticated hashes.

CentOS 7's old systemd does not provide the optional user-scope API used by
kitty. Terminal sessions still run; automatic systemd user-scope integration
is unavailable. Desktop D-Bus services require an existing session bus.
The graphical compatibility tests use kitty-software under Xvfb, including
the real CentOS 7 kernel 3.10.0-1160.el7.x86_64 and ordinary-user relocation.
Physical GPU drivers and Wayland are not covered by these tests.
