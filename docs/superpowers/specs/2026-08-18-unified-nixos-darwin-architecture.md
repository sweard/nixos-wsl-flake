# 统一 NixOS / nix-darwin 架构规格

## 目标

在一个分支中维护 WSL、原生 NixOS（VMware / 物理机）与 macOS，按“平台系统层、主机装配层、用户环境层”分离职责。

## 边界

- `hosts/` 只描述某台主机采用哪些系统模块。
- `modules/nixos/` 只包含 NixOS 系统模块；WSL 代理仅由 WSL host 导入。
- `modules/darwin/` 只包含 nix-darwin 系统模块；macOS 默认不启用代理。
- `modules/home-manager.nix` 是 NixOS 与 nix-darwin 共用的 Home Manager 装配层。
- `home/` 是所有平台共享的 Home Manager 层：
  - `common.nix`：跨平台基础配置。
  - `linux.nix`：Linux 用户目录与 Linux 增量。
  - `darwin.nix`：macOS 用户目录与 Darwin 增量。
  - `native-desktop.nix`：在 Linux 入口上增加桌面配置。
- `home/modules/` 保留可复用的细粒度功能模块。

## 主机装配

- WSL：NixOS base + WSL/WSLg + Docker + WSL proxy；Home Manager 使用 `home/linux.nix`。
- VMware / physical：NixOS base + native workstation/desktop；Home Manager 使用 `home/native-desktop.nix`。
- MacBook：Darwin base + Homebrew；Home Manager 使用 `home/darwin.nix`。

## 约束

- Linux 与 Darwin 使用各自的稳定 nixpkgs 分支，相关 input 使用 `follows` 避免同一平台重复锁定。
- Homebrew 由 `nix-homebrew` 安装/接管，由 nix-darwin `homebrew.*` 声明包；首次落地不自动清理或升级现有包。
- 代理配置不得进入跨平台 base；macOS 只有确认需要后才新增独立模块。
- 本次不启用当前注释掉的 Android/Rust/Node/Python/Flutter 重型开发模块。
- 本次不提交、不推送。
