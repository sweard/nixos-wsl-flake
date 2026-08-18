# NixOS + nix-darwin 多主机开发环境

这套 Flake 在同一个 `master` 分支中管理四个输出：`x86_64-linux` 的 NixOS-WSL 2、`aarch64-linux` 的 VMware UEFI 虚拟机、`x86_64-linux` 的 Ryzen 9 7950X + RTX 4090 物理机，以及 `aarch64-darwin` 的 MacBook。NixOS 与 nix-darwin 管系统层，`hosts/` 只装配具体主机，Home Manager 管所有平台的用户工具和 dotfiles。

## Flake 输出与主机结构

| 输出 | 主机名 | 适用环境 | 主要 adapter |
|---|---|---|---|
| `.#wsl` | `nixos-wsl` | Windows 11 / NixOS-WSL 2 | WSL、WSLg、Windows 驱动、FLClash daemon 代理 |
| `.#vmware` | `nixos-vmware` | aarch64 VMware UEFI 虚拟机 | open-vm-tools、VMware 存储/网络模块 |
| `.#physical` | `nixos-physical` | Ryzen 9 7950X + RTX 4090 物理机 | AMD 微码、KVM、NVIDIA open kernel module |
| `.#Jeffs-MacBook-Pro` | `Jeffs-MacBook-Pro` | Apple Silicon macOS | nix-darwin、现有 Homebrew 接管、Darwin Home Manager profile |

四个输出共用 `home/common.nix` 中的通用命令行工具和 zsh 配置。三个 NixOS 输出共用 NixOS base、Docker 与 Home Manager 装配；VMware 与物理机进一步共用 `native-workstation.nix` 中的 UEFI、磁盘标签约定，以及 `native-desktop.nix` 中的 Niri、Noctalia、PipeWire 和 NetworkManager。硬件差异只保留在各自的 `hosts/*/hardware.nix` 中。

当前目录边界如下：

```text
.
├── flake.nix
├── hosts/
│   ├── wsl/
│   ├── vmware/
│   ├── physical/
│   └── macbook/
├── modules/
│   ├── home-manager.nix       # NixOS 与 nix-darwin 共用的 HM 装配
│   ├── nixos/              # 只在 NixOS 求值的系统模块
│   │   ├── base.nix
│   │   ├── docker.nix
│   │   ├── wsl.nix
│   │   ├── wslg.nix
│   │   ├── wsl-proxy.nix
│   │   ├── native-workstation.nix
│   │   └── native-desktop.nix
│   └── darwin/             # 只在 nix-darwin 求值的系统模块
│       ├── base.nix
│       └── homebrew.nix
└── home/                   # 所有平台共用的 Home Manager 层
    ├── common.nix
    ├── linux.nix
    ├── darwin.nix
    ├── native-desktop.nix
    └── modules/
        ├── development/
        ├── desktop/
        └── shell/
```

`home/` 不是 Darwin 的替代分支，而是四个输出都会加载的用户层。实际组合关系是：

```text
WSL                  -> home/linux.nix           -> home/common.nix
VMware / physical    -> home/native-desktop.nix -> home/linux.nix -> home/common.nix
MacBook              -> home/darwin.nix          -> home/common.nix
```

Android、Rust、Node、Python、Flutter 和 C/C++ 模块保留在仓库中，但 `home/common.nix` 当前没有导入它们。

### Niri + Noctalia 原生桌面

VMware 与物理机使用一个原生 Wayland 会话，启动链路为：

```text
greetd/tuigreet -> niri-session -> noctalia
```

`greetd` 的文本登录界面启动 `niri-session`；Niri 的 Home Manager 配置在 compositor 启动时唯一拉起 Noctalia。Noctalia v5 当前仍是 beta。官方 Flake 的 NixOS module 只启用其推荐的系统服务；Home Manager module 唯一负责安装 Noctalia 包并生成声明式 TOML 配置，且刻意不启用其 user service，避免第二个实例。

Noctalia 接管 bar、应用启动器、通知、壁纸、锁屏、idle/OSD、剪贴板、系统托盘、MPRIS 媒体控制和 Polkit 代理。因而已移除 Plasma、SDDM、Xserver、Waybar、Fuzzel、Mako、Swaylock、NetworkManager applet、KDE Polkit 代理、`wl-clipboard`、`playerctl` 和 `brightnessctl`。仍保留 Niri、greetd 登录、portal/GNOME Keyring、PipeWire、NetworkManager、Ghostty 和 `xwayland-satellite`。

`~/.config/niri/config.kdl` 由 Home Manager 生成并管理，不能直接修改其 symlink。Home Manager 的 `backupFileExtension = "hm-backup"` 在首次接管时可能会把旧的 `~/.config/niri/config.kdl` 备份为 `config.kdl.hm-backup`。本地自定义应写进 `~/.config/niri/local.kdl`；这是 optional include，文件不存在时可忽略。Noctalia 的 GUI 状态文件 `~/.local/state/noctalia/settings.toml` 可以覆盖声明式生成的配置。

常用快捷键与当前配置一致：

- `Super+T`：打开 Ghostty。
- `Super+D` 或 `Super+Space`：打开 Noctalia launcher。
- `Super+S`：打开 Noctalia control center。
- `Alt+Tab`：打开 Noctalia window switcher。
- `Super+Alt+L`：通过 Noctalia 锁定屏幕。
- `Super+Shift+E`：退出 Niri，回到 greetd 登录界面。
- `Super+Shift+/`：显示 Niri 的完整快捷键 overlay。
- `Mod+Comma`：保留 Niri 默认的排列语义。

从 Plasma/SDDM 首次迁移时，建议先写入下一代系统并重启，而不是直接切换会话。VMware 使用：

```bash
sudo nixos-rebuild boot --flake .#vmware
sudo reboot
```

物理机使用：

```bash
sudo nixos-rebuild boot --flake .#physical
sudo reboot
```

成功迁移后，后续日常更新可以正常使用 `switch`：

```bash
sudo nixos-rebuild switch --flake .#vmware
# 或
sudo nixos-rebuild switch --flake .#physical
```

登录后可用以下稳定接口确认状态；旧组件进程的查询没有输出即为预期：

```bash
systemctl status greetd --no-pager
pgrep -a niri
pgrep -a noctalia
pgrep -a -f 'waybar|fuzzel|mako|swaylock|nm-applet|polkit-kde|wl-clipboard|playerctl|brightnessctl' || true
niri validate
noctalia config validate
noctalia msg --help
```

若新会话无法登录或验证失败，可在 boot loader 中选择上一代 generation 回退。WSL 与开发环境不导入这套原生桌面模块，不受此次迁移影响。VMware 中仍应启用虚拟机 3D 加速；物理机已为 RTX 4090 启用 NVIDIA DRM modesetting，这是 Niri Wayland 会话所需的基础条件。

### VMware 与物理机共同安装约定

原生主机配置采用一个明确、可复现的磁盘接口：

- 固件模式：UEFI；当前配置未启用 Secure Boot。
- 根文件系统：ext4，文件系统标签为 `nixos`。
- EFI System Partition：FAT32，文件系统标签为 `boot`，挂载到 `/boot`。
- 默认不声明 swap；需要时可按机器内存和休眠需求单独增加。

安装前应已经完成分区、格式化与标签设置。确认设备解析正确后挂载：

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

进入本仓库后，VMware 安装使用：

```bash
sudo nixos-install --flake .#vmware
```

物理机安装使用：

```bash
sudo nixos-install --flake .#physical
```

安装完成但重启前，为普通用户设置密码：

```bash
sudo nixos-enter --root /mnt
passwd nixos
exit
```

后续分别重建：

```bash
sudo nixos-rebuild switch --flake .#vmware
sudo nixos-rebuild switch --flake .#physical
```

VMware 虚拟机应在虚拟机设置中选择 UEFI、关闭 Secure Boot，并按需开启 3D 加速。`virtualisation.vmware.guest.enable` 会安装并启动 open-vm-tools。

`physical` adapter 专门针对 Ryzen 9 7950X + RTX 4090：启用 AMD 微码、`kvm-amd`、NVIDIA DRM modesetting 和 NVIDIA open kernel module。若物理机的 CPU、GPU、启动方式或磁盘标签不同，应先调整 `hosts/physical/hardware.nix` 与 `modules/nixos/native-workstation.nix`，不要直接套用。

原生主机和 MacBook 都没有导入代理模块，不会假设 `127.0.0.1:7890` 存在代理；只有 `.#wsl` 导入 `wsl-proxy.nix`，保留当前 Windows FLClash 代理设计。若 macOS 日后确实需要固定代理，应新增独立的 Darwin 模块，不要复用 WSL 的 systemd 配置。

## 当前实际启用的环境

| 类别 | 配置内容 |
|---|---|
| 通用用户工具 | Git、Git LFS、curl、wget、jq、ripgrep、fd、zip/unzip、tree、file、rsync、OpenSSH、GnuPG、GNU 基础工具、tealdeer、nixfmt、nil、fastfetch、Neovim、bat、eza、fzf、direnv、nix-direnv |
| 容器 | 三个 NixOS 输出启用原生 Docker daemon 与 Compose；MacBook 当前未声明容器后端 |
| Shell | zsh、由 Flake 锁定的 zinit、Powerlevel10k、现有 p10k 配置和由 zinit 管理的插件 |
| WSL / WSLg | usbutils、pciutils、Mesa/OpenGL、Vulkan、Wayland 和 X11 诊断工具、MesloLGS Nerd Font |
| 原生桌面 | VMware 与物理机启用 Niri、Noctalia、greetd/tuigreet、Ghostty、xwayland-satellite、PipeWire、NetworkManager |
| macOS | nix-darwin、nix-homebrew，以及由 Home Manager 管理的通用用户工具和 zsh |

Git 身份当前由 `home/modules/development/common.nix` 声明为 `sweord <sweord@hotmail.com>`，并会应用到四个输出。私人网络变量、令牌和其他秘密没有写入仓库；可复制 `~/.config/zsh/local.zsh.example` 为 `~/.config/zsh/local.zsh` 后自行填写。

## 仓库保留但默认未启用的开发模块

以下文件仍在仓库中，但它们在 `home/common.nix` 中的 import 当前均被注释，因此不会进入任何 host 的 Home Manager profile，也不会因为默认重建而下载对应工具链：

| 模块 | 文件中声明的能力 | 当前状态 |
|---|---|---|
| C/C++ | GCC、Clang/LLVM、LLDB、GDB、Make、CMake、Ninja、ccache、Autotools | 未导入 |
| Android/JVM | Android Studio、API 34–36、Build Tools 34/35/36、NDK 26/28、CMake 3.22.1、JDK 21、Gradle、Kotlin | 未导入 |
| Rust | stable、cargo、rustfmt、clippy、rust-analyzer、rust-src、4 个 Android targets、sccache | 未导入 |
| Node | Node.js 24、pnpm | 未导入 |
| Python | Python 3、virtualenv、pipx | 未导入 |
| Flutter | Nixpkgs 26.05 中的 Flutter | 未导入 |

这些文件是从既有开发环境迁移时保留下来的候选配置，不代表当前系统已经安装对应工具。若在 `home/common.nix` 直接启用，会同时影响 Linux 与 macOS；若只针对某类环境，应改在 `home/linux.nix`、`home/darwin.nix` 或 `home/native-desktop.nix` 导入。启用前还需确认 `x86_64-linux`、`aarch64-linux` 和 `aarch64-darwin` 的包兼容性。

当前默认配置没有直接安装 `pkg-config`、Node、Python、Rust、JDK、Android SDK 或 Flutter。项目需要这些工具时，优先考虑项目自己的 `devShell`；若确实希望全局提供，再启用对应 Home Manager 模块。

## zsh 配置

zsh 已迁移以下实际启用项：

- zinit annex：as-monitor、bin-gem-node、patch-dl、rust。
- zsh-history-substring-search、zsh-autosuggestions、zsh-completions、zsh-syntax-highlighting。
- Oh My Zsh 的 z、git；检测到 `brew` 命令时才加载 brew snippet。
- romkatv/powerlevel10k 与当前 `~/.p10k.zsh` 的逐字副本。

zinit 本体由 `flake.lock` 锁定，但 zinit 下载的插件和 snippets 继续使用其原生生命周期，并不由 `flake.lock` 固定。当前默认 profile 也没有启用 Node、Python 或 Android 模块，因此不能把 nvm、pyenv 或手写 Android PATH 视为已经由 Nix 工具链替代。

## macOS / nix-darwin 首次接入

MacBook 输出使用用户 `sbwoan`、主机名 `Jeffs-MacBook-Pro` 和 `aarch64-darwin`。本机已有的 `/opt/homebrew` 由 `nix-homebrew` 迁移接管；当前不额外安装 `/usr/local` 下的 Intel Homebrew。`autoMigrate = true` 会在首次 activation 删除原 Homebrew 代码仓库、保留已安装包，再换成 Nix 管理的 Homebrew 实现；`cleanup = "none"` 只表示不删除未声明 formula/cask，并不等于迁移本身无状态变更。

首次迁移前先确认标准路径、检查 Homebrew 仓库是否有本地修改，并导出当前清单：

```bash
brew --prefix
git -C "$(brew --repository)" status --short
brew bundle dump --file="$HOME/Brewfile.before-nix-homebrew" --force
brew tap > "$HOME/brew-taps.before-nix-homebrew.txt"
```

如果 Homebrew 仓库存在需要保留的本地修改，应先单独备份或提交，不要直接 activation。

macOS 需要先安装官方多用户 Nix；当前配置保留 nix-darwin 默认的 `nix.enable = true`，不兼容 Determinate Nix。若使用 Determinate Nix，需要先设计 `nix.enable = false` 的独立变体，不能直接套用本配置。进入仓库后，为新增 inputs 生成锁定信息并检查输出：

```bash
nix --extra-experimental-features 'nix-command flakes' flake lock
nix --extra-experimental-features 'nix-command flakes' flake show
```

首次安装 nix-darwin：

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake .#Jeffs-MacBook-Pro
```

之后日常应用：

```bash
sudo darwin-rebuild switch --flake .#Jeffs-MacBook-Pro
```

当前 Darwin 配置只接入系统基础、Homebrew 管理入口和通用 Home Manager profile，不启用 Niri/Noctalia、Docker、WSLg 或 WSL 代理。

## 1. Windows 侧准备

### 1.1 更新 WSL

在管理员 PowerShell 中运行：

```powershell
wsl --update
wsl --shutdown
```

### 1.2 配置 WSL 2

把 `windows/.wslconfig.example` 复制到：

```text
%UserProfile%\.wslconfig
```

推荐内容：

```ini
# Ryzen 9 7950X: 32 logical processors.
# Keep memory dynamic; do not hard-code a memory limit.
[wsl2]
processors=32
guiApplications=true
nestedVirtualization=true
localhostForwarding=true
networkingMode=mirrored
dnsTunneling=true
autoProxy=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

应用：

```powershell
wsl --shutdown
```

这套配置依赖 mirrored networking，使 NixOS-WSL 可以通过 `127.0.0.1` 访问 Windows 上的 FLClash；`autoProxy=true` 会尝试把 Windows 系统代理同步到普通 WSL shell。

### 1.3 Windows / FLClash

推荐：

- FLClash 开启 TUN 模式，或开启 Windows 系统代理。
- 记下 Mixed Port；本文以下统一假设为 `7890`。
- mirrored 模式下一般不需要开启“允许局域网”。
- Windows 安装支持 WSL 的最新 NVIDIA 驱动，以供 WSLg / RTX 4090 使用。
- Windows Terminal 如需正确显示 Powerlevel10k 图标，安装 MesloLGS Nerd Font v3。

### 1.4 安装 NixOS-WSL

从 NixOS-WSL Releases 下载 `nixos.wsl`。WSL 2.4.4 及以上可运行：

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS
```

进入：

```powershell
wsl -d NixOS
```

---

## 2. 全新安装 Quick Start

这一节按顺序执行即可。第一次安装不要先依赖 VS Code Remote；先完成系统切换和 WSL 重启，再连接 VS Code。

### 2.1 设置 `nixos` 用户密码

全新 NixOS-WSL 先执行：

```bash
passwd
```

后续 `sudo` 会要求这个密码。

如果已经进入“`sudo` 要求密码，但用户从未设置密码”的状态，可在 Windows PowerShell 中：

```powershell
wsl -d NixOS -u root
```

然后：

```bash
passwd nixos
exit
```

### 2.2 把 Flake 放入 Linux 文件系统

推荐：

```text
/home/nixos/nixos-wsl-flake
```

不要直接在 `/mnt/c`、`/mnt/d` 等 Windows 挂载盘中构建大型 Nix 项目；Linux 文件系统的 I/O、权限语义和文件监控行为更合适。

进入目录：

```bash
cd ~/nixos-wsl-flake
```

### 2.3 确认普通 shell 已获得 Windows 代理

```bash
env | grep -i proxy
```

在当前 FLClash 配置下，应该能看到类似：

```text
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
```

继续测试：

```bash
curl -I https://github.com
curl -I https://cache.nixos.org/nix-cache-info
```

还可以直接指定 Mixed Port：

```bash
curl -x http://127.0.0.1:7890 \
  -I https://cache.nixos.org/nix-cache-info
```

即使目标是 HTTPS，HTTP/Mixed 代理地址通常仍写作：

```text
http://127.0.0.1:7890
```

由 HTTP CONNECT 建立 HTTPS 隧道。

### 2.4 第一次构建前，临时给 `nix-daemon` 注入代理

这里是全新安装最重要的 bootstrap 步骤。

WSL `autoProxy=true` 能给用户 shell 设置代理，但 systemd 管理的 `nix-daemon` 不会自动继承用户环境。第一次 `nixos-rebuild` 之前，永久的 `modules/nixos/wsl-proxy.nix` 还没有生效，因此先创建仅当前启动有效的 runtime override：

```bash
sudo mkdir -p /run/systemd/system/nix-daemon.service.d

sudo tee /run/systemd/system/nix-daemon.service.d/proxy.conf >/dev/null <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="http_proxy=http://127.0.0.1:7890"
Environment="https_proxy=http://127.0.0.1:7890"
EOF

sudo systemctl daemon-reload
sudo systemctl restart nix-daemon.service
```

确认：

```bash
systemctl show nix-daemon.service -p Environment
```

应看到 `HTTP_PROXY` / `HTTPS_PROXY`。

`/run` 是临时运行时目录；WSL/NixOS 重启后这个 override 会消失。第一次系统切换成功后，`modules/nixos/wsl-proxy.nix` 会永久接管 `nix-daemon`、Docker daemon 与 sudo 代理变量保留规则。

### 2.5 首次检查 Flake

全新镜像可能尚未全局开启 `nix-command` / `flakes`，因此首次命令显式开启：

```bash
nix --extra-experimental-features 'nix-command flakes' flake metadata .

nix --extra-experimental-features 'nix-command flakes' flake show
```

如果直接运行 `nix flake ...` 时出现：

```text
error: experimental Nix feature 'nix-command' is disabled
```

这不是网络错误。

此时也不要用：

```bash
docker pull hello-world
```

来判断网络，因为 Docker 尚未由本 Flake 安装。

### 2.6 第一次 `nixos-rebuild`

第一次重建需要同时覆盖两条网络链路：

```text
sudo/nixos-rebuild -> GitHub / Flake inputs
nix-daemon        -> cache.nixos.org
```

因此第一次使用：

```bash
sudo env \
  HTTP_PROXY=http://127.0.0.1:7890 \
  HTTPS_PROXY=http://127.0.0.1:7890 \
  http_proxy=http://127.0.0.1:7890 \
  https_proxy=http://127.0.0.1:7890 \
  NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake .#wsl
```

按当前默认 imports，第一次构建会下载 NixOS 基础系统、Docker、通用命令行工具、zsh/zinit，以及 WSL/WSLg 所需的图形和诊断工具；不会下载仓库中默认未启用的 Android SDK/NDK、Flutter、Rust、完整 C/C++ 工具链、JDK 或 Node。实际下载量取决于现有 Nix store 和二进制缓存命中情况。

如果进度长时间停在：

```text
fetching ... from https://cache.nixos.org
```

优先检查：

```bash
systemctl show nix-daemon.service -p Environment
```

如果出现：

```text
https://github.com/...tar.gz
Connection timed out after 15000 milliseconds
```

优先检查 root/sudo 是否获得代理：

```bash
sudo env | grep -i proxy
```

### 2.7 完全重启 WSL

第一次系统切换完成后，在 Windows PowerShell：

```powershell
wsl --shutdown
wsl -d NixOS
```

这一步很重要，因为它会让 `/etc/wsl.conf`、DrvFs automount、WSLg、用户 shell、systemd 服务和永久代理全部从冷启动状态重新加载。

---

## 3. 首次启动验证

重新进入 NixOS 后执行：

```bash
nix flake metadata .

docker --version

systemctl is-active nix-daemon
systemctl is-active docker
```

预期两个 systemd 服务均返回：

```text
active
```

确认永久 daemon 代理：

```bash
systemctl show nix-daemon.service -p Environment
systemctl show docker.service -p Environment
```

两者都应该包含：

```text
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
```

确认 `sudo` 会保留 WSL 自动注入的代理：

```bash
env | grep -i proxy
sudo env | grep -i proxy
```

`modules/nixos/wsl-proxy.nix` 已声明：

```nix
security.sudo.extraConfig = ''
  Defaults env_keep += "HTTP_PROXY HTTPS_PROXY NO_PROXY"
  Defaults env_keep += "http_proxy https_proxy no_proxy"
'';
```

因此以后应可以直接运行：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

无需长期使用 `sudo -E`，也无需每次手写 `sudo env HTTP_PROXY=...`。

再验证 Docker：

```bash
docker run --rm hello-world
```

项目还提供一个完整开发能力盘点脚本：

```bash
bash scripts/doctor.sh
```

该脚本会同时检查当前已启用工具和默认未启用的 Java、Android、Rust、Node、Python、Flutter、C/C++ 工具，因此按当前默认 profile 运行时会报告多项 `MISSING` 并返回非零状态。这是能力清单结果，不表示基础系统切换失败。

当前默认 profile 可重点确认：

```bash
command -v git zsh docker nixfmt nil
git --version
zsh --version
docker --version
```

WSLg：

```bash
glxinfo -B
vulkaninfo --summary
```

`android-studio` 只有在启用 Android Home Manager 模块并成功重建后才会存在。

---

## 4. Windows VS Code 连接 NixOS-WSL

推荐使用 **Windows 版 VS Code + Microsoft WSL 扩展**，不需要给 NixOS 额外配置 SSH server。

首次系统切换和 `wsl --shutdown` 完成后，在 VS Code 命令面板执行：

```text
WSL: Connect to WSL
```

选择：

```text
NixOS
```

然后打开：

```text
/home/nixos/nixos-wsl-flake
```

也可以进入 NixOS 后：

```bash
cd ~/nixos-wsl-flake
code .
```

### 4.1 `wslServer.sh: Permission denied`

本配置的 `modules/nixos/wsl.nix` 已使用：

```text
metadata,uid=1000,gid=100,umask=022,fmask=022
```

这是为了允许 VS Code WSL 扩展执行 Windows 文件系统中的：

```text
wslServer.sh
wslDownload.sh
```

如果 VS Code 日志出现：

```text
.../ms-vscode-remote.remote-wsl-.../scripts/wslServer.sh: Permission denied
```

检查：

```bash
mount | grep ' /mnt/c '
```

不要出现：

```text
fmask=111
```

`fmask=111` 会屏蔽普通文件的所有执行位，使 VS Code Remote WSL 的脚本变成 `-rw-r--r--`。

修改 automount 配置后必须执行：

```powershell
wsl --shutdown
wsl -d NixOS
```

才能重新挂载 `/mnt/c`。

不建议把手工 `chmod +x` VS Code 扩展目录作为长期解决方案，因为 VS Code WSL 扩展升级后脚本目录会变化。

---

## 5. 网络与代理设计

当前配置把代理职责分为三层：

```text
Windows FLClash / WSL autoProxy
    |
    +-- 普通用户 shell
    |
    +-- sudo
    |     `-- wsl-proxy.nix 的 env_keep
    |
    +-- systemd daemons
          +-- nix-daemon -> wsl-proxy.nix
          `-- docker     -> wsl-proxy.nix
```

`modules/nixos/wsl-proxy.nix` 当前固定使用：

```text
http://127.0.0.1:7890
```

如果 FLClash Mixed Port 改变，需要同步修改该文件。

### 5.1 为什么不把代理再次写进 `environment.sessionVariables`

普通 shell 已由 WSL `autoProxy=true` 自动处理。NixOS 只显式管理 systemd daemon，可以避免 WSL 自动代理和 NixOS shell 变量两套机制互相覆盖。

### 5.2 mirrored 网络下的推荐配置

mirrored networking 下，WSL 可以直接访问 Windows `127.0.0.1`，因此 FLClash 通常无需开启“允许局域网”。

### 5.3 NAT 网络备用方案

如果没有使用 mirrored networking，WSL 中的 `127.0.0.1` 不是 Windows 回环地址。

取得 Windows 主机 IP：

```bash
ip route show default | awk '{print $3}'
```

例如：

```text
172.30.96.1
```

则代理可能需要改为：

```text
http://172.30.96.1:7890
```

此模式下 FLClash 通常还需要允许 LAN / 监听 `0.0.0.0`，Windows/Hyper-V 防火墙也要允许访问。WSL NAT 主机 IP 可能随重启改变，因此本配置优先使用 mirrored networking。

### 5.4 下载源

先保证官方源可以稳定访问：

```text
https://cache.nixos.org
https://github.com
https://dl.google.com/android/repository/
```

不要在排障初期同时替换多个第三方 binary cache 或镜像源，否则会增加 DNS、代理、证书、缓存签名问题的判断难度。

---

## 6. 第一次构建会包含什么

第一次 `nixos-rebuild` 需要把当前 host 的系统 closure 加入 `/nix/store`。按当前默认配置，WSL 主要包含 NixOS 基础系统、Docker、通用 Home Manager 工具、zsh/zinit、字体和 WSLg 诊断工具；原生主机还会包含 Niri、Noctalia、greetd、Ghostty、PipeWire 与 NetworkManager。

Android SDK/NDK、Flutter、Rust、JDK、Node 和完整 C/C++ 工具链当前没有导入，不属于默认 closure。只有将对应开发模块启用后，后续重建才会下载它们，并可能显著增加 `/nix/store` 占用。

构建过程中可能看到类似进度：

```text
[0/N built, ... copied (...), ... DL]
```

并不意味着每次重建都会重新下载这些内容。

Nix 会复用已有 store paths。第一次系统成功后，普通配置修改再执行：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

通常会快得多。


## 7. 可选 Android、ADB 与模拟器配置

Android Home Manager 模块当前默认未导入，因此默认 profile 中没有 `android-studio`、`adb`、JDK、Gradle、Kotlin、Android SDK/NDK，也不会设置 `ANDROID_SDK_ROOT`、`ANDROID_HOME`、`JAVA_HOME` 或 NDK 路径。

如果确认要把 Android 工具链加入所有平台，可在 `home/common.nix` 中启用 `./modules/development/android.nix` 后重建；通常更合理的是只在 `home/linux.nix` 中导入。启用后，SDK 位于 Nix store 的只读组合结果；SDK 版本应通过修改 `home/modules/development/android.nix` 后重建，不要在 Android Studio 的 SDK Manager 中直接修改该只读 SDK。

注意，`home/linux.nix` 当前由 WSL、VMware 与物理机共用，而 VMware 是 `aarch64-linux`。直接在这里启用 Android module 会同时作用于三者；应先验证 Android Studio 和 Android SDK 中预编译工具的 ARM Linux 兼容性。只需要 WSL 时，应再增加更具体的 Home Manager profile，而不是把 host 判断散落到开发模块中。

Android module 自身把 Emulator 和 system image 保持为关闭状态。启用该 module 后，在 WSL 中仍推荐：

1. 在 Windows 侧运行 Android Emulator，项目源码与 Gradle 构建留在 WSL；或
2. 使用无线调试的 `adb pair` / `adb connect`；或
3. 用 usbipd-win 把真实 USB Android 设备附加给 WSL。

USB/IP 在 NixOS 侧已启用。Windows 管理员 PowerShell 中可先查看并附加设备：

```powershell
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

启用 Android module 后，可在 WSL 中运行 `adb devices`。如确实要实验 WSL 内模拟器，把 Android 模块中的 `includeEmulator` 改成 `true` 并添加 system image；这会显著增加下载体积，且图形/KVM 加速兼容性取决于当前 WSL 版本。

## 8. Docker 后端

默认启用的是 NixOS 内原生 Docker daemon，`nixos` 用户已加入 `docker` 组。没有启用 Docker Desktop integration，避免两个 daemon 混用。

如果决定统一改用 Windows Docker Desktop：

- 在 `modules/nixos/docker.nix` 中关闭 `virtualisation.docker.enable`；
- 把 `wsl.docker-desktop.enable` 改为 `true`；
- 在 Docker Desktop 设置中启用该 NixOS WSL 发行版。

## 9. WSL 下 7950X 与 RTX 4090 的职责划分

- 本节只描述 `.#wsl`。7950X 的微码、核心调度和 WSL Linux 内核由 Windows/WSL 管理，NixOS-WSL 不安装裸机 AMD 微码模块。Nix 构建已使用 `max-jobs = auto` 和全部可用核心。
- 在 `.#wsl` 中，RTX 4090 的内核驱动同样安装在 Windows，不要启用 `hardware.nvidia`。`wsl.useWindowsDriver = true` 会接入 Windows 提供的 WSL 图形库，供 WSLg/OpenGL 使用；`.#physical` 则由 NixOS 管理 NVIDIA 驱动。
- 如果 Windows 驱动暴露了工具，可运行 `/usr/lib/wsl/lib/nvidia-smi` 检查 GPU。CUDA Toolkit 与 NVIDIA Container Toolkit 不在本次所选环境内，需要时应单独增加模块并独立验证。

## 10. 更新与回滚

更新所有 Flake 输入并重建：

```bash
cd ~/nixos-wsl-flake
nix flake update
sudo nixos-rebuild switch --flake .#wsl
```

MacBook 更新并重建：

```bash
nix flake update
sudo darwin-rebuild switch --flake .#Jeffs-MacBook-Pro
```

以下代次、回滚与每周 GC 说明只适用于三个 NixOS 输出：

```bash
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

`system.stateVersion` 与 `home.stateVersion` 不应随着普通升级随意修改，它们表示首次采用该配置时的兼容基线。

NixOS 会每周回收 14 天前已不再使用的 Nix store 路径；需要长期保留某个旧系统代次时，请在清理前为它保留可达引用，或关闭 `modules/nixos/base.nix` 中的自动 GC。Darwin 当前没有声明自动 GC；可用 `darwin-rebuild --list-generations` 查看代次，回滚前应先根据该命令输出选择目标 generation。
