# Niri + Noctalia 原生桌面规格

## 目标

将 VMware 与物理机共用的原生 NixOS 桌面从 Plasma 6 与 Niri 双会话，收敛为仅 Niri 窗口管理器与 Noctalia v5 原生 Wayland shell。WSL 和开发环境保持不变。

## 官方依据

- Noctalia v5 使用 `github:noctalia-dev/noctalia` Flake；通过其 NixOS 与 Home Manager module 安装和声明配置。
- Noctalia 由 Wayland compositor 的启动项拉起；Niri 使用 `spawn-at-startup "noctalia"`，不额外启用 Noctalia systemd user service。
- Noctalia 提供 bar、launcher、notifications、wallpaper、lock screen、idle、OSD、clipboard、tray、MPRIS media controls 与可选 Polkit agent。
- Noctalia 不替代 compositor、display/login manager、portal、文件管理器与 X11 compatibility layer。
- Noctalia 的完整 Wi-Fi、Bluetooth、battery 和 power-profile 集成需要 NetworkManager、Bluetooth、UPower 与 power-profiles-daemon（或 tuned）。

## 设计

- 保留 Nixpkgs 26.05 的 `programs.niri`，继续由它注册 `niri-session`、portal、GNOME Keyring 与屏幕共享集成。
- 删除 Plasma 6、SDDM/KWin 与 X server；使用最小化 `greetd + tuigreet`，认证后直接执行 `niri-session`。
- 添加 Noctalia Flake input，并令其 `nixpkgs` 跟随仓库的 Nixpkgs 26.05，以保持 Wayland/GL 运行时与系统一致；精确提交由 `flake.lock` 固定。
- 在原生桌面模块导入 Noctalia NixOS module，启用推荐服务但不重复安装 package；在原生主机对应的 Home Manager 用户子模块导入 Noctalia Home Manager module，由 Home Manager 唯一安装 package 并声明基础配置。
- 由 Home Manager 从锁定的 Niri 包自带 `default-config.kdl` 生成用户配置：保留上游完整默认键位，只替换 Waybar/Fuzzel/Swaylock/Alacritty、音量/亮度和媒体命令为 Noctalia/Ghostty；追加官方 Niri window rule、activation debug setting 与 Noctalia 快捷键。
- Noctalia 通过 Niri `spawn-at-startup` 启动；Noctalia 的 Home Manager systemd service 保持关闭，避免双启动。
- Noctalia 配置显式开启内置 Polkit agent；通知、锁屏、壁纸、剪贴板、bar 与 launcher 使用 v5 默认启用状态。

## 移除或禁用

- Plasma 6、SDDM、KWin greeter 与 `services.xserver`。
- VMware 中仅为 Plasma session restore 设置的 `ksmserverrc`。
- Waybar、Fuzzel、Mako、Swaylock、NetworkManager applet、KDE Polkit agent、`wl-clipboard`、`playerctl` 与 `brightnessctl`。
- Niri 专用 Mako 与 KDE Polkit systemd user services。

## 保留

- Niri、PipeWire/WirePlumber、NetworkManager、rtkit、dconf、hardware graphics。
- Ghostty 作为终端。
- `xwayland-satellite` 作为 Niri 的 X11 compatibility layer。
- Nixpkgs Niri module 提供的 portal、Nautilus file chooser 与 GNOME Keyring。
- VMware/物理机硬件、UEFI、Docker、Home Manager、shell 与所有开发工具配置。

## 验收条件

- `.#vmware` 与 `.#physical` 只注册/启动 Niri 桌面，不启用 Plasma/SDDM/X server。
- WSL 不导入或安装 Noctalia/Niri 原生桌面模块。
- Noctalia v5 package 由官方 Flake 锁定且只进入用户 profile，NixOS 与 Home Manager imports 均可求值。
- 登录后仅启动一个 Noctalia 实例，不启动 Waybar、Mako、Swaylock 或 KDE Polkit agent。
- bar、launcher、notifications、wallpaper、lock screen、clipboard、tray、media/volume/brightness controls 与 Polkit prompt 由 Noctalia 提供。
- `niri validate` 能验证生成的 `~/.config/niri/config.kdl`；Noctalia 的 `config validate` 能验证声明式 TOML。
- README 给出首次切换、关键快捷键、验证和回退排错步骤。
- 不修改任何与桌面无关的开发环境文件，不创建分支，不 commit，不 push。
