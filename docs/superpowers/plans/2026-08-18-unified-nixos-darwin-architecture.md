# Unified NixOS / Darwin Architecture Implementation Plan

> **For Codex:** Execute this plan incrementally with structural tests before implementation. Do not commit or push without explicit user approval.

**Goal:** 将 WSL、原生 NixOS 与 macOS 配置统一到一个分支，同时保持系统模块和 Home Manager 平台入口边界清晰。

**Architecture:** `flake.nix` 负责按主机选择系统模块与 Home Manager 入口；`modules/nixos`、`modules/darwin` 分别承载系统层；`home/common.nix` 被 Linux、Darwin 和原生桌面入口复用。WSL 代理保持为 WSL 专属能力。

**Tech Stack:** Nix Flakes、NixOS、nix-darwin、Home Manager、nix-homebrew、Bash 结构测试。

**Spec:** `docs/superpowers/specs/2026-08-18-unified-nixos-darwin-architecture.md`

---

### Task 1: 固化架构约束

- [x] 新增 `tests/unified-platform-architecture.sh`。
- [x] 验证测试在实现前因缺少 Darwin / Home 平台入口而失败。

### Task 2: 拆分 Home Manager 平台入口

- [x] 将原 `home/default.nix` 的跨平台配置迁入 `home/common.nix`。
- [x] 新增 `home/linux.nix`、`home/darwin.nix` 和 `home/native-desktop.nix`。
- [x] 让 NixOS Home Manager 模块通过 `homeProfile` 装配对应入口。
- [x] 从 NixOS desktop 系统模块移除 Home Manager 桌面配置注入。

### Task 3: 接入 macOS

- [x] 在 `flake.nix` 添加稳定 Darwin nixpkgs、nix-darwin 和 nix-homebrew inputs。
- [x] 新增 `modules/darwin/base.nix`、`homebrew.nix`，并抽取共享的 `modules/home-manager.nix`。
- [x] 新增 `hosts/macbook/default.nix` 并输出 `darwinConfigurations`。
- [x] 为 `aarch64-darwin` 提供 formatter。

### Task 4: 收敛代理边界

- [x] 将 `modules/nixos/proxy.nix` 更名为 `wsl-proxy.nix`。
- [x] 将代理相关 sudo 环境保留规则从 NixOS base 移入 WSL proxy。
- [x] 确认只有 WSL host 导入该模块。

### Task 5: 文档与验证

- [x] 按真实结构更新 README 的主机矩阵、目录树和应用命令。
- [x] 运行两组结构测试及 shell 语法检查。
- [x] 若 Nix 可用，执行 flake check/eval；否则明确记录 lock 与求值验证限制。
- [x] 检查最终 diff，确认无意外文件、提交或推送。
