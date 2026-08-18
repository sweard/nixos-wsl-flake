# Plasma 与 Niri 可切换桌面方案

## 目标

在 `feat/native-nixos-hosts` 分支保留现有 Plasma 6 桌面，并为 VMware 与物理机增加可从登录界面选择的 Niri 会话。WSL 配置保持不变。

## 设计

- 使用 Nixpkgs 26.05 内置的 `programs.niri` 模块，不额外引入 Niri Flake。
- 继续使用 SDDM。Plasma 6 已把 SDDM greeter 配置为 KWin Wayland，并注册 Plasma 会话；Niri 模块注册 `niri` Wayland 会话。用户在 SDDM 的会话菜单中选择二者。
- Plasma 6 保持默认会话，避免升级后改变现有行为。
- PipeWire + WirePlumber 提供音频，NetworkManager 提供网络；两种桌面共用同一系统服务。
- Niri 使用上游默认 KDL 配置，以减少复制和后续升级维护。安装默认配置引用的 Waybar、Fuzzel、Alacritty 与 Swaylock。
- 增加 Mako 通知守护进程、NetworkManager applet、剪贴板和媒体/亮度工具。
- 安装 `xwayland-satellite`，由 Niri 26.04 按需启动以兼容 X11 应用。
- 使用绑定到 `niri.service` 的 systemd user service 启动 Mako 与 KDE Polkit 认证代理；退出 Niri 后随会话停止，不干扰 Plasma。
- Niri 的 portal、Nautilus 文件选择器、GNOME Keyring 与屏幕共享支持交给 Nixpkgs 的 `programs.niri` 模块管理。

## 验收条件

- VMware 与物理机继续提供 Plasma 6，并新增 `niri` 会话。
- SDDM greeter 使用 Wayland，默认会话仍为 `plasma`。
- Niri 会话具备终端、启动器、状态栏、锁屏、通知、认证、网络托盘、剪贴板及 X11 兼容能力。
- PipeWire 和 NetworkManager 保持启用。
- WSL 不引入 Niri 或原生桌面依赖。
- README 说明如何在 SDDM 切换桌面，以及 Niri 默认快捷键和配置路径。
