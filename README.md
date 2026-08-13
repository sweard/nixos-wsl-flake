# NixOS-WSL 开发环境

这套 Flake 面向 Ryzen 9 7950X + RTX 4090 的 Windows 主机，系统目标是 `x86_64-linux` 的 NixOS-WSL 2。它把职责分为三个 seam：NixOS 管系统与 daemon，NixOS-WSL 管 Windows 接入，Home Manager 管开发工具和 dotfiles。

## 已纳入的环境

| 类别 | 配置内容 |
|---|---|
| Android/JVM | Android Studio、API 34–36、Build Tools 34/35/36、platform-tools/ADB、NDK 26/28、CMake 3.22.1、JDK 21、Gradle、Kotlin |
| Rust | stable、cargo、rustfmt、clippy、rust-analyzer、rust-src、4 个 Android targets、sccache |
| Node | Node.js 24、pnpm |
| C/C++ | GCC、Clang/LLVM、LLDB、GDB、Make、CMake、Ninja、ccache、Autotools |
| Python | Python 3、virtualenv、pipx |
| Flutter | Nixpkgs 26.05 中的 Flutter，使用同一套 Android SDK/JDK |
| 通用 | Git、Git LFS、curl、wget、jq、ripgrep、fd、zip/unzip、rsync、SSH、GnuPG、direnv |
| 容器 | NixOS 内原生 Docker daemon 与 Compose |
| Shell | zsh、zinit、Powerlevel10k、现有 p10k 配置和现有插件 |

没有直接安装 `pkg-config`。因此 Android/Flutter Android 开发不受影响，但 Flutter Linux 桌面工程可能在 `flutter doctor` 中提示缺少它；需要时只在项目自己的 `devShell` 中加入即可。

## 从当前环境迁移的依据

扫描到的当前环境包括：zsh 5.9；Node 24.15/22.15 与 pnpm 11.19；JDK 21；Android API 29、32–36，Build Tools 29–36，NDK 25–28 和 CMake 3.22.1；Rust stable 1.94 及 Android targets；Flutter 3.41.4 stable；Docker 29.7；Git 2.55；CMake 4.4；Python 3.9。

这套配置保留组件能力，但不是把每个历史版本都复制一遍：Android 选择仍常用的 API 34–36、Build Tools 34–36、NDK 26/28；Node 固定主版本 24；Python 采用 26.05 官方仍支持的 `python3`（`python3Full` 已被上游移除），Flutter 跟随锁定后的 Nixpkgs 26.05。最终精确版本由 `flake.lock` 固定。

zsh 已迁移以下实际启用项：

- zinit annex：as-monitor、bin-gem-node、patch-dl、rust。
- zsh-history-substring-search、zsh-autosuggestions、zsh-completions、zsh-syntax-highlighting。
- Oh My Zsh 的 z、git；brew 仅在 WSL 中确实存在 `brew` 时加载。
- romkatv/powerlevel10k 与当前 `~/.p10k.zsh` 的逐字副本。

nvm、pyenv 和手写 Android PATH 被 Nix/Home Manager 取代。私人局域网变量、Git 姓名邮箱和令牌没有写进配置，可复制 `~/.config/zsh/local.zsh.example` 为 `local.zsh` 后自行填写。

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

WSL `autoProxy=true` 能给用户 shell 设置代理，但 systemd 管理的 `nix-daemon` 不会自动继承用户环境。第一次 `nixos-rebuild` 之前，永久的 `modules/nixos/proxy.nix` 还没有生效，因此先创建仅当前启动有效的 runtime override：

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

`/run` 是临时运行时目录；WSL/NixOS 重启后这个 override 会消失。第一次系统切换成功后，`modules/nixos/proxy.nix` 会永久接管 `nix-daemon` 和 Docker daemon 的代理。

### 2.5 首次检查 Flake

全新镜像可能尚未全局开启 `nix-command` / `flakes`，因此首次命令显式开启：

```bash
nix --extra-experimental-features 'nix-command flakes' flake lock

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

第一次构建会下载 Android SDK/NDK、Flutter、Rust、LLVM、JDK、Docker、Node 等大量依赖。数 GiB 的网络下载和十余 GiB 的 Nix store 数据属于正常现象。

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
nix flake metadata github:NixOS/nixpkgs

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

`modules/nixos/base.nix` 已声明：

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

最后执行项目自带检查：

```bash
bash scripts/doctor.sh
```

也可以逐项确认：

```bash
java -version
adb version
rustc --version
node --version
pnpm --version
flutter doctor -v
```

WSLg：

```bash
glxinfo -B
vulkaninfo --summary
android-studio
```

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
    |     `-- base.nix 的 env_keep
    |
    +-- systemd daemons
          +-- nix-daemon -> proxy.nix
          `-- docker     -> proxy.nix
```

`modules/nixos/proxy.nix` 当前固定使用：

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

## 6. 为什么第一次构建特别慢

第一次 `nixos-rebuild` 需要把整套开发环境加入 `/nix/store`，包括 Android SDK/NDK、Flutter、Rust、JDK、LLVM、Node、Docker 等。

进度类似：

```text
[0/733 built, ... copied (.../11.8 GiB), .../5.6 GiB DL]
```

并不意味着每次重建都会重新下载这些内容。

Nix 会复用已有 store paths。第一次系统成功后，普通配置修改再执行：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

通常会快得多。


## 7. Android、ADB 与模拟器

Android SDK 位于 Nix store 的只读组合结果，`ANDROID_SDK_ROOT`、`ANDROID_HOME`、`JAVA_HOME` 和 NDK 路径已自动设置。SDK 版本应通过修改 `home/modules/development/android.nix` 后重建，不要在 Android Studio 的 SDK Manager 中直接修改该只读 SDK。

WSL 内默认不包含 Android Emulator/system image。推荐方案是：

1. 在 Windows 侧运行 Android Emulator，项目源码与 Gradle 构建留在 WSL；或
2. 使用无线调试的 `adb pair` / `adb connect`；或
3. 用 usbipd-win 把真实 USB Android 设备附加给 WSL。

USB/IP 在 NixOS 侧已启用。Windows 管理员 PowerShell 中可先查看并附加设备：

```powershell
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

然后在 WSL 中运行 `adb devices`。如确实要实验 WSL 内模拟器，把 Android 模块中的 `includeEmulator` 改成 `true` 并添加 system image；这会显著增加下载体积，且图形/KVM 加速兼容性取决于当前 WSL 版本。

## 8. Docker 后端

默认启用的是 NixOS 内原生 Docker daemon，`nixos` 用户已加入 `docker` 组。没有启用 Docker Desktop integration，避免两个 daemon 混用。

如果决定统一改用 Windows Docker Desktop：

- 在 `modules/nixos/docker.nix` 中关闭 `virtualisation.docker.enable`；
- 把 `wsl.docker-desktop.enable` 改为 `true`；
- 在 Docker Desktop 设置中启用该 NixOS WSL 发行版。

## 9. 7950X 与 RTX 4090 的职责划分

- 7950X 的微码、核心调度和 WSL Linux 内核由 Windows/WSL 管理，NixOS-WSL 不安装裸机 AMD 微码模块。Nix 构建已使用 `max-jobs = auto` 和全部可用核心。
- RTX 4090 的内核驱动同样安装在 Windows，不要在 NixOS-WSL 中启用 `hardware.nvidia`。`wsl.useWindowsDriver = true` 会接入 Windows 提供的 WSL 图形库，供 WSLg/OpenGL 使用。
- 如果 Windows 驱动暴露了工具，可运行 `/usr/lib/wsl/lib/nvidia-smi` 检查 GPU。CUDA Toolkit 与 NVIDIA Container Toolkit 不在本次所选环境内，需要时应单独增加模块并独立验证。

## 10. 更新与回滚

更新所有 Flake 输入并重建：

```bash
cd ~/nixos-wsl-flake
nix flake update
sudo nixos-rebuild switch --flake .#wsl
```

列出系统代次并回滚：

```bash
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

`system.stateVersion` 与 `home.stateVersion` 不应随着普通升级随意修改，它们表示首次采用该配置时的兼容基线。

系统会每周回收 14 天前已不再使用的 Nix store 路径；需要长期保留某个旧系统代次时，请在清理前为它保留可达引用，或关闭 `modules/nixos/base.nix` 中的自动 GC。
