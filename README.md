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

版本固定在 `tools/build-inside.sh`：tmux 3.5a、Neovim 0.10.4、fish 3.7.1、starship 1.22.1、ripgrep 14.1.1、exa 0.10.1、bat 0.24.0、fd 10.2.0、fzf 0.60.3、zoxide 0.9.6、delta 0.18.2、procs 0.14.8、mcfly 0.9.3。exa 按清单保留原项目，没有替换成 eza。

使用 Rust 1.85.0 和 Go 1.23.6，避免自动升级工具链而改变内核要求。CPU 使用 x86-64 基线，不使用 `native`、AVX2 或 x86-64-v3。Cargo 使用 `--locked`。fish 3.7.1 的 CMake 一律拒绝 `-static`；脚本仅在 musl 构建中移除该检查，并对最终 ELF 重新审计。

源码版本固定不等于完全可复现构建：容器基础标签、Alpine 仓库更新和上游发布归档仍是外部输入。包内 `SOURCES.sha256` 记录下载归档哈希（不是预先固定的可信校验值），`VERSIONS` 记录工具版本，`SHA256SUMS` 记录二进制及资源哈希。

## 验证结果

本次构建的 13 个工具已通过静态 ELF 审计和下述真实内核冒烟测试。发布包约 49 MB，包哈希见 `build/kernel-test/PASS`。

每个安装的 ELF 都必须通过 `readelf` 审计：无 `PT_INTERP`、无 `DT_NEEDED`。随后 QEMU 使用 TCG 软件模拟和 `qemu64` CPU，无需 KVM，启动 CentOS 7 官方 RPM 中的 **3.10.0-1160.el7.x86_64** 内核。RPM 由 CentOS GPG 密钥验证。

guest 是无共享库的精简 initramfs，不是完整 CentOS 用户空间；内核是真实 CentOS 7 内核。检查包括 tmux 会话和 PTY、Neovim headless 文件读取、fish 计算、rg/fd/fzf 搜索、bat/exa/procs 运行、zoxide 数据库操作，以及剩余工具启动和 shell 初始化。它是基础功能冒烟测试，不等于所有交互、插件和网络路径均经过测试。

仅测试成功时生成 `build/kernel-test/PASS`，内容为对应发布包的 SHA-256。完整串口日志在 `build/kernel-test/serial.log`。失败或未测试的包不可宣称已通过 CentOS 7 内核验证。

参考：[Rust 平台要求](https://doc.rust-lang.org/rustc/platform-support.html)、[Neovim 静态构建说明](https://neovim.io/doc/build/)、[fish 3.7.1 构建配置](https://github.com/fish-shell/fish-shell/blob/3.7.1/CMakeLists.txt)。
