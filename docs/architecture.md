# NixOS / nix-darwin / generic Linux Home Manager 统一架构

## 目标

在一个分支中维护 WSL、原生 NixOS（VMware / 物理机）、macOS 与 Ubuntu/Arch Linux 用户环境，按“平台系统层、主机装配层、用户环境层”分离职责。

## 边界

- `hosts/` 只描述某台主机采用哪些系统模块。
- `modules/nixos/` 只包含 NixOS 系统模块；WSL 代理仅由 WSL host 导入。
- `modules/darwin/` 只包含 nix-darwin 系统模块；macOS 默认不启用代理。
- `modules/home-manager.nix` 是 NixOS 与 nix-darwin 共用的 Home Manager 装配层。
- 非 NixOS Linux 不经过系统 module 装配，直接由 `homeConfigurations.jeff-aarch64-linux` 调用 standalone Home Manager。
- `home/` 是所有平台共享的 Home Manager 层：
  - `common.nix`：跨平台基础配置。
  - `linux.nix`：Linux 用户目录与 Linux 增量。
  - `generic-linux.nix`：在 Linux 入口上增加非 NixOS 的 Home Manager 集成。
  - `darwin.nix`：macOS 用户目录与 Darwin 增量。
  - `native-desktop.nix`：在 Linux 入口上增加桌面配置。
- `home/modules/` 保留可复用的细粒度功能模块。
  - `cli.nix`：所有用户共享的 CLI、Git 与 direnv 配置。
  - `development/`：按需启用的语言和 SDK 工具链。
  - `desktop/`：仅原生 Linux 桌面使用的用户应用与配置。

## 主机装配

- WSL：NixOS base + WSL/WSLg + Docker + WSL proxy；Home Manager 使用 `home/linux.nix`。
- VMware / physical：NixOS base + native workstation/desktop；Home Manager 使用 `home/native-desktop.nix`。
- MacBook：Darwin base + Homebrew；Home Manager 使用 `home/darwin.nix`。
- Ubuntu / Arch Linux：系统仍由宿主发行版管理；独立 Home Manager 输出使用 `home/generic-linux.nix`，仅复用用户工具和 dotfiles。

## 约束

- Linux 与 Darwin 使用各自的稳定 nixpkgs 分支，相关 input 使用 `follows` 避免同一平台重复锁定。
- Homebrew 由 `nix-homebrew` 安装/接管，由 nix-darwin `homebrew.*` 声明包；首次落地不自动清理或升级现有包。
- 代理配置不得进入跨平台 base；macOS 只有确认需要后才新增独立模块。
- 用户应用和 dotfiles 由 Home Manager 管理；daemon、驱动、会话兼容层和系统权限由 NixOS 或 nix-darwin 管理。
- 非 NixOS Linux 不导入 NixOS modules 或原生桌面 profile；Docker、SSH、桌面会话和其他系统服务继续使用宿主发行版的管理方式。
- Android 只能通过 `modules/nixos/android-development.nix` 启用，使 SDK license 与 Home Manager 工具链保持原子化。
- Rust overlay 由 Rust Home Manager module 局部扩展，不得进入所有 NixOS host 的全局 `pkgs`。
- 当前默认 profile 不启用 Android、Rust、Node、Python、Flutter 或 C/C++ 重型开发模块。
