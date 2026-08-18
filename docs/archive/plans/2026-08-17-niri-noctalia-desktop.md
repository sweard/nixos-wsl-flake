# Niri + Noctalia 原生桌面实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 VMware 与物理机的桌面收敛为 Niri + Noctalia v5，并移除可被 Noctalia 替代的 Plasma 与零散 shell 组件。

**Architecture:** `native-workstation.nix` 继续作为原生主机入口；`native-desktop.nix` 负责 Niri、greetd、系统服务与 Noctalia NixOS module；新增的 Home Manager 桌面模块负责 Noctalia 设置和基于 Niri 上游默认配置生成集成后的 `config.kdl`。Noctalia 只在原生主机的 Home Manager 用户子模块中导入，WSL 路径不变。

**Tech Stack:** Nix Flakes、NixOS/Home Manager 26.05、Niri 26.04、Noctalia v5、greetd/tuigreet、PipeWire、NetworkManager。

**Spec:** `docs/superpowers/specs/2026-08-17-niri-noctalia-desktop.md`

## Global Constraints

- 保留 Niri，使用当前锁定的 Nixpkgs 26.05 package/module。
- Noctalia 使用 `github:noctalia-dev/noctalia`，其 `nixpkgs` 跟随仓库的 `nixpkgs`。
- Noctalia 由 Niri compositor autostart 启动，不同时启用 Noctalia systemd user service。
- VMware 与 physical 共用该桌面；WSL 不引入原生桌面依赖。
- 不修改开发环境模块、Docker、proxy、WSL/WSLg 或硬件模块。
- 不创建分支，不 commit，不 push。

---

### Task 1: 建立桌面架构回归检查

**Files:**
- Create: `tests/native-desktop-noctalia.sh`

**Interfaces:**
- Consumes: `flake.nix`、`modules/nixos/native-desktop.nix`、`home/modules/desktop/noctalia.nix`、`hosts/vmware/default.nix` 与 `README.md`。
- Produces: 一个无 Nix runtime 也可运行的结构检查，验证 input/import、组件去重、WSL 隔离与文档关键项。

- [ ] **Step 1: 写入预期新架构的失败检查**

脚本使用 `rg -F` 要求出现 `github:noctalia-dev/noctalia`、两个官方 module import、`spawn-at-startup "noctalia"`、greetd、Ghostty 与 xwayland-satellite；同时拒绝 active Plasma/SDDM/Waybar/Fuzzel/Mako/Swaylock/KDE Polkit package/service 配置。

- [ ] **Step 2: 运行检查并确认因功能尚未实现而失败**

Run: `bash tests/native-desktop-noctalia.sh`

Expected: 非零退出；首个失败点是缺少 Noctalia Flake input 或 Home Manager 桌面模块，而不是 shell 语法错误。

### Task 2: 接入 Noctalia Flake 与原生桌面 modules

**Files:**
- Modify: `flake.nix`
- Modify: `modules/nixos/native-desktop.nix`
- Create: `home/modules/desktop/noctalia.nix`

**Interfaces:**
- Consumes: `inputs.noctalia.nixosModules.default`、`inputs.noctalia.homeModules.default`、Nixpkgs `programs.niri`、`pkgs.niri.doc`、greetd/tuigreet 与 Noctalia IPC。
- Produces: 仅原生主机启用的 Niri + Noctalia session，以及 Home Manager 管理的 Noctalia TOML 与 Niri KDL。

- [ ] **Step 1: 添加并传递 Noctalia input**

在 `inputs` 中增加：

```nix
noctalia = {
  url = "github:noctalia-dev/noctalia";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

现有 `inputs@{ ... }` 与 `specialArgs = { inherit inputs userSettings; };` 已满足 module 参数传递，不复制单独的 `noctalia` 参数。

- [ ] **Step 2: 将 display manager 收敛为 greetd + niri**

在 `native-desktop.nix` 导入 `inputs.noctalia.nixosModules.default`，删除 Plasma/SDDM/X server，配置：

```nix
services.greetd = {
  enable = true;
  useTextGreeter = true;
  settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.niri}/bin/niri-session";
};

programs.niri.enable = true;
programs.noctalia = {
  enable = true;
  package = null;
  recommendedServices.enable = true;
};
```

NixOS module 只负责推荐系统服务，package 由 Home Manager 唯一安装；不启用 `programs.noctalia.systemd.enable`，避免与 Niri autostart 重复。

- [ ] **Step 3: 只保留 Noctalia 不替代的桌面 package**

`environment.systemPackages` 只保留：

```nix
with pkgs; [
  ghostty
  xwayland-satellite
]
```

删除 Mako/KDE Polkit user services；保留 PipeWire、NetworkManager、rtkit、dconf 与 graphics。

- [ ] **Step 4: 在原生用户 Home Manager 子模块导入 Noctalia**

追加：

```nix
home-manager.users.${userSettings.username}.imports = [
  inputs.noctalia.homeModules.default
  ../../home/modules/desktop/noctalia.nix
];
```

该定义只存在于 `native-desktop.nix`，因此 WSL 的 `home/default.nix` 不导入 Noctalia。

- [ ] **Step 5: 声明 Noctalia 基础配置**

新增 Home Manager 模块：

```nix
programs.noctalia = {
  enable = true;
  systemd.enable = false;
  settings = {
    shell.polkit_agent = true;
    theme = {
      mode = "dark";
      source = "builtin";
      builtin = "Noctalia";
    };
  };
};
```

- [ ] **Step 6: 从 Niri 26.04 上游默认配置生成集成配置**

使用 `pkgs.runCommand` 复制 `${pkgs.niri.doc}/share/doc/niri/default-config.kdl`，通过 `substituteInPlace --replace-fail` 精确替换 Waybar、Alacritty、Fuzzel、Swaylock、wpctl、playerctl 与 brightnessctl 行；在文件末尾追加官方 Noctalia autostart、settings window rule、activation debug setting、launcher/control-center/window-switcher binds 和 stationary wallpaper layer rule，并加入 `include optional=true "~/.config/niri/local.kdl"`。

- [ ] **Step 7: 重跑结构检查**

Run: `bash tests/native-desktop-noctalia.sh`

Expected: PASS。

### Task 3: 清理 VMware Plasma 遗留并更新操作文档

**Files:**
- Modify: `hosts/vmware/default.nix`
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 2 的 greetd、Noctalia/Niri 启动方式和快捷键。
- Produces: 无 Plasma workaround 的 VMware adapter，以及首次应用与验证手册。

- [ ] **Step 1: 删除 Plasma session restore workaround**

删除 `hosts/vmware/default.nix` 的 `environment.etc."xdg/ksmserverrc"`，保留 kernel 与 OpenSSH 配置。

- [ ] **Step 2: 重写原生桌面说明**

README 将原“Plasma 与 Niri 桌面切换”改为“Niri + Noctalia 原生桌面”，列出：

```text
greetd/tuigreet -> niri-session -> noctalia
```

并说明已移除的组件、Noctalia v5 beta 状态、`~/.config/niri/config.kdl` 的 Home Manager 管理方式、`~/.config/niri/local.kdl` 本地覆盖、首次应用命令、快捷键和验证命令。

- [ ] **Step 3: 重跑结构检查与 Markdown 差异检查**

Run: `bash tests/native-desktop-noctalia.sh && git diff --check`

Expected: 两个命令均退出 0。

### Task 4: 锁定依赖并完成验证

**Files:**
- Modify: `flake.lock`
- Verify: 所有变更文件。

**Interfaces:**
- Consumes: 完整 Flake 和结构检查。
- Produces: 可重现的 Noctalia revision 与验证证据。

- [ ] **Step 1: 更新 Noctalia lock node**

Run: `nix flake lock --update-input noctalia`

Expected: `flake.lock` 新增 `noctalia` node，并记录其锁定 Git revision；现有 inputs 不做无关升级。

- [ ] **Step 2: 格式化变更的 Nix 文件**

Run: `nix fmt flake.nix modules/nixos/native-desktop.nix home/modules/desktop/noctalia.nix hosts/vmware/default.nix`

Expected: exit 0。

- [ ] **Step 3: 求值两个原生主机与 WSL 隔离**

Run:

```bash
nix eval --raw .#nixosConfigurations.vmware.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.physical.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.wsl.config.system.build.toplevel.drvPath
```

Expected: 三个命令均输出 store derivation path；WSL 不求值原生桌面 Home Manager module。

- [ ] **Step 4: 完整静态验证**

Run:

```bash
bash -n tests/native-desktop-noctalia.sh
bash tests/native-desktop-noctalia.sh
git diff --check
git status --short
```

Expected: shell 语法、结构检查与 whitespace 检查通过；状态只包含本计划列出的桌面、文档、测试和 lock 文件。

- [ ] **Step 5: 自审最终差异**

确认 Plasma/SDDM/Waybar/Fuzzel/Mako/Swaylock/KDE Polkit agent 不再 active；Ghostty、xwayland-satellite、portal、GNOME Keyring、PipeWire 与 NetworkManager 保留；Noctalia 只由 Niri autostart 一次；README 命令与实际文件一致。
