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

在管理员 PowerShell 中更新 WSL：

```powershell
wsl --update
wsl --shutdown
```

从 NixOS-WSL Releases 下载最新的 `nixos.wsl`。WSL 2.4.4 及以上可以双击安装，也可以运行：

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS
```

如需明确启用 7950X 的 32 个逻辑处理器和 WSLg，可把 `windows/.wslconfig.example` 复制到 `%UserProfile%\.wslconfig`，再运行 `wsl --shutdown`。没有写死内存上限，避免在不知道主机内存容量时做错误限制。

WSLg 还要求 Windows 安装支持 WSL 的最新 NVIDIA 驱动。Powerlevel10k 在 Windows Terminal 中显示正确图标，则需要在 Windows 安装 MesloLGS Nerd Font v3，并在 Terminal 配置中选用它；NixOS 内也已安装对应字体，供 WSLg GUI 使用。

## 2. 中国网络与 Windows FLClash

如果 Windows 正在运行 FLClash，NixOS-WSL 不一定需要额外写死代理。推荐按以下顺序配置：

1. Windows 使用较新的 WSL 2，并启用镜像网络。
2. FLClash 开启 TUN 模式，或开启 Windows 系统代理。
3. 先验证 WSL、Nix daemon 和 Docker 是否已经能联网。
4. 只有终端可以联网、Nix daemon 或 Docker 仍然失败时，才添加显式代理模块。

### 2.1 推荐：镜像网络与自动代理

Windows 11 22H2 及以上可在 `%UserProfile%\.wslconfig` 中使用：

```ini
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

应用配置：

```powershell
wsl --shutdown
wsl -d NixOS
```

镜像网络允许 WSL 通过 `127.0.0.1` 访问 Windows 服务，`autoProxy=true` 会尝试把 Windows HTTP 系统代理同步到 WSL。相关行为以 [Microsoft WSL 网络文档](https://learn.microsoft.com/zh-cn/windows/wsl/networking) 为准。

FLClash 侧建议：

- 优先使用 TUN 模式，或者开启“系统代理”。
- 记下 FLClash 的 Mixed Port（混合端口），下面以 `7890` 为例。
- 镜像网络下通常不需要开启“允许局域网”；避免无意中把代理暴露给整个局域网。
- 如果 FLClash 只监听 `127.0.0.1`，镜像网络通常仍可从 WSL 访问。

测试 Windows 代理端口：

```zsh
curl -x http://127.0.0.1:7890 \
  -I https://cache.nixos.org/nix-cache-info
```

即使访问的是 HTTPS 网站，HTTP/Mixed 代理地址通常仍写成 `http://127.0.0.1:7890`，由 HTTP CONNECT 建立隧道；不要在未确认端口协议时改成 `https://127.0.0.1:7890`。

### 2.2 先判断是否需要显式代理

进入 NixOS-WSL 后运行：

```zsh
env | grep -i proxy
curl -I https://github.com
curl -I https://cache.nixos.org/nix-cache-info
nix flake metadata github:NixOS/nixpkgs
docker pull hello-world
```

如果这些命令都成功，就不需要再把代理地址写入 NixOS。这样 FLClash 未启动时，NixOS 仍可直接联网，也不会因固定端口变化而失效。

### 2.3 终端能联网，但 Nix 或 Docker 不能联网

只在 zsh 中设置 `HTTP_PROXY` 并不保证系统级 `nix-daemon` 和 Docker daemon 能看到它。Nix 官方也要求多用户 daemon 获得对应的代理环境变量，参见 [Nix 代理环境变量文档](https://releases.nixos.org/nix/nix-2.31.2/manual/installation/env-variables.html)。

如有需要，可创建 `modules/nixos/proxy.nix`，把 `7890` 换成 FLClash 实际 Mixed Port：

```nix
{ ... }:

let
  proxy = "http://127.0.0.1:7890";
  noProxy = "localhost,127.0.0.1,::1,.local";
  proxyEnvironment = {
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    ALL_PROXY = proxy;
    NO_PROXY = noProxy;
    http_proxy = proxy;
    https_proxy = proxy;
    all_proxy = proxy;
    no_proxy = noProxy;
  };
in
{
  environment.sessionVariables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;
  systemd.services.docker.environment = proxyEnvironment;
}
```

在 `hosts/wsl/default.nix` 的 `imports` 中加入：

```nix
../../modules/nixos/proxy.nix
```

然后应用并重启两个 daemon：

```zsh
sudo nixos-rebuild switch --flake .#wsl
sudo systemctl restart nix-daemon.service
sudo systemctl restart docker.service
```

显式代理模块的代价是：FLClash 没有运行、监听端口改变或代理不可用时，Nix 和 Docker 也会无法联网。因此只要 TUN/自动代理已经覆盖 WSL，就不建议启用此模块。如果代理包含用户名、密码或令牌，不要把认证信息直接写进 Flake；Nix 配置可能进入可读的 Nix store。

### 2.4 备用：WSL 默认 NAT 网络

没有使用 mirrored 模式时，WSL 中的 `127.0.0.1` 不是 Windows 的回环地址。先在 WSL 中取得 Windows 主机 IP：

```zsh
ip route show default | awk '{print $3}'
```

假设输出 `172.30.96.1`，代理地址就是：

```text
http://172.30.96.1:7890
```

此时 FLClash 通常需要开启“允许局域网”并监听 `0.0.0.0`，Windows/Hyper-V 防火墙也必须允许 WSL 访问该端口。开放 LAN 监听会扩大暴露面，应仅允许可信网络和必要端口。NAT 模式下 Windows 主机 IP 可能在 WSL 重启后改变，因此不适合直接硬编码进 Nix 模块。

### 2.5 下载源建议

先确保以下官方源能稳定通过 FLClash：

- `https://cache.nixos.org`
- `https://github.com`
- `https://dl.google.com/android/repository/`

不要一开始就同时更换多个第三方 Nix 二进制缓存或软件源。先保持官方源不变，更容易区分代理、DNS、证书和缓存签名问题；确认代理链路稳定后，再按实际速度决定是否增加可信缓存。

## 3. 首次部署

把本目录放到 NixOS-WSL 的 Linux 文件系统，例如 `~/nixos-wsl-flake`。不要从 `/mnt/c` 直接构建大型项目；Linux 文件系统的权限语义和 I/O 表现更合适。

默认用户名是 NixOS-WSL 镜像已有的 `nixos`。如果镜像中已安全创建别的用户，先修改 `flake.nix` 的 `userSettings.username`，并同步确认 `/home/<用户名>` 与 UID。

先为默认用户设置密码，后续 sudo 会正常要求该密码：

```bash
passwd
```

首次锁定输入并检查配置：

```bash
cd ~/nixos-wsl-flake
nix --extra-experimental-features 'nix-command flakes' flake lock
nix --extra-experimental-features 'nix-command flakes' flake show
```

应用系统与 Home Manager：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

回到 Windows PowerShell 重启 WSL：

```powershell
wsl --shutdown
wsl -d NixOS
```

首次进入 zsh 时，zinit 会下载插件。zinit 本体由 Flake 锁定，插件仍由 zinit 原生管理；更新插件使用 `zinit update --all`。

## 4. 验证

```bash
bash scripts/doctor.sh
java -version
adb version
rustc --version
node --version
pnpm --version
flutter doctor -v
docker run --rm hello-world
```

WSLg 图形链路可检查：

```bash
glxinfo -B
vulkaninfo --summary
android-studio
```

## 5. Android、ADB 与模拟器

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

## 6. Docker 后端

默认启用的是 NixOS 内原生 Docker daemon，`nixos` 用户已加入 `docker` 组。没有启用 Docker Desktop integration，避免两个 daemon 混用。

如果决定统一改用 Windows Docker Desktop：

- 在 `modules/nixos/docker.nix` 中关闭 `virtualisation.docker.enable`；
- 把 `wsl.docker-desktop.enable` 改为 `true`；
- 在 Docker Desktop 设置中启用该 NixOS WSL 发行版。

## 7. 7950X 与 RTX 4090 的职责划分

- 7950X 的微码、核心调度和 WSL Linux 内核由 Windows/WSL 管理，NixOS-WSL 不安装裸机 AMD 微码模块。Nix 构建已使用 `max-jobs = auto` 和全部可用核心。
- RTX 4090 的内核驱动同样安装在 Windows，不要在 NixOS-WSL 中启用 `hardware.nvidia`。`wsl.useWindowsDriver = true` 会接入 Windows 提供的 WSL 图形库，供 WSLg/OpenGL 使用。
- 如果 Windows 驱动暴露了工具，可运行 `/usr/lib/wsl/lib/nvidia-smi` 检查 GPU。CUDA Toolkit 与 NVIDIA Container Toolkit 不在本次所选环境内，需要时应单独增加模块并独立验证。

## 8. 更新与回滚

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
