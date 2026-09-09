# modern-linux：CentOS 7 静态工具包

读取 `list.txt`，从源码构建全部 13 个工具。目标是 **x86_64、musl 全静态 ELF、CentOS 7 的 3.10 内核**。默认流程包括 QEMU 全系统验证，不以 CentOS 容器中的运行结果代替旧内核测试。

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

“无依赖”在这里指**无动态加载器、无共享库依赖，目标机无须安装库包**。编辑器 runtime、shell 函数和终端数据库作为包内资源分发。它不意味着凭空提供 git、SSH、剪贴板服务、语言服务器、编译器或任意插件的依赖；调用这些可选功能仍需对应外部程序。tmux 中启动的默认 shell 由系统提供。

全静态 musl 不支持 `dlopen` 动态扩展：Neovim 禁用随包 Tree-sitter `.so` 解析器，不能加载外部 C/Lua 动态模块；内置 Lua、常规编辑及传统语法高亮仍可使用。若需要这些动态插件功能，就不能同时保持这里的严格全静态约束。

## 版本及兼容性策略

以 2026-09-09 官方 GitHub latest release 为准，版本固定在 `tools/build-inside.sh`，查询记录见 `tools/releases.json`。不使用 nightly 或预发布版本。

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

exa 已替换为 eza，命令名改为 `eza`。使用固定的 Rust 1.98.1 和 Go 1.27.1；升级编译器不等于提高目标机器的内核要求，最终以全系统测试为准。CPU 使用 x86-64 基线，不使用 `native`、AVX2 或 x86-64-v3。Cargo 使用 `--locked`。fish 4.x 使用 Rust 和静态 PCRE2，已移除旧版 fish 3.7.1 的 CMake 补丁。

源码版本固定不等于完全可复现构建：容器基础标签、Alpine 仓库更新和上游发布归档仍是外部输入。包内 `SOURCES.sha256` 记录下载归档哈希（不是预先固定的可信校验值），`VERSIONS` 记录工具版本，`TOOLCHAIN` 记录实际编译器版本，`RELEASES.json` 保存上游版本查询记录，`SHA256SUMS` 记录二进制及资源哈希。

## 验证结果

2026-09-09：上述 13 个工具全部通过静态 ELF 审计和真实 CentOS 7 内核冒烟测试，未发生版本回退。发布包约 47 MB；`build/kernel-test/PASS` 记录对应包的 SHA-256。

每个安装的 ELF 都必须通过 `readelf` 审计：无 `PT_INTERP`、无 `DT_NEEDED`。随后 QEMU 使用 TCG 软件模拟和 `qemu64` CPU，无需 KVM，启动 CentOS 7 官方 RPM 中的 **3.10.0-1160.el7.x86_64** 内核。RPM 由 CentOS GPG 密钥验证。

guest 是无共享库的精简 initramfs，不是完整 CentOS 用户空间；内核是真实 CentOS 7 内核。检查包括 tmux 会话和 PTY、Neovim headless 文件读写、子进程及 PTY、fish 计算和随机数、rg/fd/fzf 搜索、bat/eza/procs 运行、zoxide 数据库操作、McFly 历史记录写入和导出、starship 提示符生成、delta 差异渲染及 shell 初始化。它是基础功能冒烟测试，不等于所有交互、插件和网络路径均经过测试。

仅测试成功时生成 `build/kernel-test/PASS`，内容为对应发布包的 SHA-256。完整串口日志在 `build/kernel-test/serial.log`。失败或未测试的包不可宣称已通过 CentOS 7 内核验证。

参考：[Rust 平台要求](https://doc.rust-lang.org/rustc/platform-support.html)、[Neovim 静态构建说明](https://neovim.io/doc/build/)、[fish 4.9.3 构建配置](https://github.com/fish-shell/fish-shell/blob/4.9.3/CMakeLists.txt)。
