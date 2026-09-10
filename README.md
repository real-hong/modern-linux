# modern-linux：CentOS 7 静态工具包

另有独立的 **GCC 16.2.0 / Binutils 2.47 C/C++ 工具链**：`bash build-gcc.sh` 构建，`bash tools/test-gcc.sh` 验证，输出 `dist/gcc-16.2.0-centos7-x86_64.tar.gz`，不混入下面的工具包。以 CentOS 7 glibc 2.17 构建，携带 GCC 运行库及开发 sysroot；支持解压到用户目录，无须 sudo，环境脚本自动定位安装路径。详见 [GCC 包说明](tools/gcc-README.txt)。

2026-09-10：GCC 独立包约 98 MiB，86 个 ELF 通过 glibc ≤ 2.17 依赖审计；干净 CentOS 7 容器及 QEMU 的真实 `3.10.0-1160.el7.x86_64` 内核均通过 C23、C++23、PIE、多线程、异常、LTO、OpenMP、共享库、LTO 静态归档及静态 C++ 运行库链接冒烟测试。结果见 `build/gcc/container-test.log`、`build/gcc/kernel-test/serial.log`；`build/gcc/kernel-test/PASS` 记录通过测试的压缩包 SHA-256。未运行完整 GCC 上游测试套件。

另以 UID 12345 的普通用户在 CentOS 7 容器中解压并移动安装目录，在 `/opt/gcc-16.2.0` 不存在的情况下通过同一组编译运行测试，日志为 `build/gcc/unprivileged-test.log`。

读取 `list.txt`，从源码构建全部 18 个工具。目标是 **x86_64、静态可执行文件、CentOS 7 的 3.10 内核**。除 Valgrind 使用 CentOS 7 glibc 构建并携带必需的预加载模块外，其余工具使用 musl 全静态构建。默认流程包括 QEMU 全系统验证，不以 CentOS 容器中的运行结果代替旧内核测试。

```sh
./build.sh          # 编译 + 静态审计 + CentOS 7 内核冒烟测试
./build.sh build    # 只编译，不代表已经验证旧内核兼容
./build.sh test     # 对 dist 中的包运行静态审计及旧内核测试
```

构建机需要 x86_64 Linux、Bash、Podman（或 `ENGINE=docker`）、网络、足够的磁盘空间；建议至少 8 GB 内存、20 GB 可用空间。`JOBS=2 ./build.sh` 可降低编译并行度。构建依赖全部安装在容器内。源码及 Cargo/Go 下载缓存保存在 `build/`。首次构建较慢。

输出为 `dist/modern-linux-x86_64.tar.gz`。在目标机器上安装：

```sh
sudo tar xzf modern-linux-x86_64.tar.gz -C /
. /opt/modern-linux/env.sh
```

使用固定路径 `/opt/modern-linux`，确保 fish、Neovim 和 terminfo 能找到随包携带的资源。`neovim` 的命令名为 `nvim`，`ripgrep` 为 `rg`，`fd` 为 `fd`，`delta` 为 `delta`。不要只复制 `bin/`。

除下面说明的 Valgrind 例外，“无依赖”指**可执行文件无动态加载器、无共享库依赖，目标机无须为这些可执行文件安装库包**。编辑器 runtime、shell 函数和终端数据库作为包内资源分发。包中包含 Git；SSH、剪贴板服务、语言服务器、编译器和 Make/Ninja 等构建后端仍由目标环境提供；调用这些可选功能仍需对应外部程序。tmux 中启动的默认 shell 由系统提供。

全静态 musl 不支持 `dlopen` 动态扩展：Neovim 禁用随包 Tree-sitter `.so` 解析器，不能加载外部 C/Lua 动态模块；内置 Lua、常规编辑及传统语法高亮仍可使用。GDB 禁用 Python、Guile、debuginfod 等可选集成，支持本地调试和 TUI；Python pretty-printer 不可用；静态 musl 构建不能加载目标 glibc 的 `libthread_db`，不保证 glibc 多线程调试功能。CGDB 使用包内 GDB。

Valgrind 的启动程序、工具引擎及辅助 ELF 均静态链接；仅放行 `libexec/valgrind/` 中六个固定名称的 `vgpreload_*-amd64-linux.so` 模块。这些模块注入被测程序，依赖该程序使用的 glibc（CentOS 7 为 2.17），不能宣称整个包完全不含共享库。Valgrind 面向 CentOS 7 glibc 程序；其分析报告脚本需要目标机器的 Perl。对静态被测程序，内存分配拦截有额外限制，参见 [Valgrind FAQ](https://valgrind.org/docs/manual/faq.html)。

Git 使用专用静态 libcurl 8.22.0，包含 HTTP/HTTPS 传输辅助程序，随包提供 CA 证书；SSH 传输需要外部 SSH。禁用可选 Rust 子系统以及 Perl、Python 和 Tcl/Tk 辅助功能（例如 git-svn、git-send-email、git-gui）。CMake 同时提供 `ctest`、`cpack` 和完整模块资源，不包含编译器；禁用 GUI 和 curses 配置界面。

## 版本及兼容性策略

以 2026-09-09 各项目官方稳定发布页为准，版本固定在 `tools/build-inside.sh`，查询记录见 `tools/releases.json`。不使用 nightly 或预发布版本。

| 工具 | 原版本 | 已验证版本 |
| --- | --- | --- |
| tmux | 3.5a | 3.7c |
| Neovim | 0.10.4 | 0.12.5 |
| fish | 3.7.1 | 4.9.3 |
| starship | 1.22.1 | 1.26.0 |
| ripgrep | 14.1.1 | 15.2.0 |
| eza | exa 0.10.1 | 0.23.5 |
| bat | 0.24.0 | 0.26.1 |
| fd | 10.2.0 | 10.5.0 |
| fzf | 0.60.3 | 0.74.3 |
| zoxide | 0.9.6 | 0.10.0 |
| delta | 0.18.2 | 0.19.2 |
| procs | 0.14.8 | 0.14.12 |
| mcfly | 0.9.3 | 0.9.4 |
| GDB | 新增 | 17.2 |
| CGDB | 新增 | 0.8.0 |
| Valgrind | 新增 | 3.27.1 |
| Git | 新增 | 2.55.0 |
| CMake | 新增 | 4.4.3 |

exa 已替换为 eza，命令名改为 `eza`。使用固定的 Rust 1.98.1 和 Go 1.27.1；升级编译器不等于提高目标机器的内核要求，最终以全系统测试为准。CPU 使用 x86-64 基线，不使用 `native`、AVX2 或 x86-64-v3。Cargo 使用 `--locked`。fish 4.x 使用 Rust 和静态 PCRE2，已移除旧版 fish 3.7.1 的 CMake 补丁。

源码版本固定不等于完全可复现构建：容器基础标签、Alpine 仓库更新和上游发布归档仍是外部输入。包内 `SOURCES.sha256` 记录下载归档哈希（不是预先固定的可信校验值），`VERSIONS` 记录工具版本，`TOOLCHAIN` 记录实际编译器版本，`RELEASES.json` 保存上游版本查询记录，`SHA256SUMS` 记录二进制及资源哈希。

## 验证结果

2026-09-10：全部 18 个工具通过 ELF 审计和真实 CentOS 7 内核冒烟测试。发布包约 289 MB；`build/kernel-test/PASS` 记录对应发布包的 SHA-256。Git 和 CMake 另在 CentOS 7 用户空间中通过 HTTPS 访问及证书校验（使用构建机内核，不代表旧内核网络路径已验证）。

所有目录中的 ELF（包括 `libexec` 辅助程序）都必须通过 `readelf` 审计：可执行文件无 `PT_INTERP`、无 `DT_NEEDED`；Valgrind 的六个预加载模块允许为共享 ELF，但同样不得声明 `DT_NEEDED` 或动态加载器，所需符号由被测 glibc 进程提供。随后 QEMU 使用 TCG 软件模拟和 `qemu64` CPU，无需 KVM，启动 CentOS 7 官方 RPM 中的 **3.10.0-1160.el7.x86_64** 内核。RPM 由 CentOS GPG 密钥验证。

guest 是精简 initramfs，不是完整 CentOS 用户空间；内核是真实 CentOS 7 内核。仅为 Valgrind 的 glibc 测试程序额外放入 CentOS 7 动态加载器和 libc，这些测试文件不进入发布包。检查包括 tmux 会话和 PTY、Neovim headless 文件读写、子进程及 PTY、fish 计算和随机数、rg/fd/fzf 搜索、bat/eza/procs 运行、zoxide 数据库操作、McFly 历史记录写入和导出、starship 提示符生成、delta 差异渲染及 shell 初始化。新增检查包括 GDB 断点和被调试进程运行、CGDB PTY 交互断点、Valgrind 正常程序与越界写入检测、Git 提交/克隆/对象校验，以及 CMake 配置、CTest 执行和 CPack 打包。它是基础功能冒烟测试，不等于所有交互、插件和网络路径均经过测试。

仅测试成功时生成 `build/kernel-test/PASS`，内容为对应发布包的 SHA-256。完整串口日志在 `build/kernel-test/serial.log`。`bash tools/test-audit.sh` 可验证静态审计会拒绝动态辅助程序、损坏的二进制、未放行的共享模块和额外动态依赖。失败或未测试的包不可宣称已通过 CentOS 7 内核验证。

参考：[Rust 平台要求](https://doc.rust-lang.org/rustc/platform-support.html)、[Neovim 静态构建说明](https://neovim.io/doc/build/)、[fish 4.9.3 构建配置](https://github.com/fish-shell/fish-shell/blob/4.9.3/CMakeLists.txt)。
