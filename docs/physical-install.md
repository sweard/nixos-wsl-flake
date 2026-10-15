# physical 核显双系统安装指南

适用于 Ryzen 9 7950X、64 GB 内存、独立空白 SSD 的 NixOS 安装。Windows 11 留在原有磁盘，NixOS 只使用接在主板核显输出上的显示器。两个系统先通过主板 UEFI 启动菜单切换，不共享 EFI 分区，也不设置 Windows 链式引导。

仓库是待填写磁盘信息的模板：安装前必须替换两个 UUID 占位，并准备完整的 Mihomo 配置。不要把模板直接应用到已运行的系统。

## 配置范围

| 文件 | physical 专属设置 |
|---|---|
| `hosts/physical/default.nix` | 导入原生工作站和代理模块，EFI 挂载点 `/boot`，启动等待 5 秒，最多保留 10 个引导 generation，本地时间 RTC |
| `hosts/physical/hardware.nix` | AMD 微码、AMDGPU、KVM、NVIDIA/Nouveau 黑名单、根分区和 ESP 的 UUID |
| `modules/nixos/native-proxy.nix` | Mihomo、显式代理环境变量、清华二进制缓存 |
| `/etc/mihomo/config.yaml` | 实机运行时文件，含订阅或节点凭据，不属于仓库 |

Niri、Noctalia、PipeWire、NetworkManager 和 Home Manager 继续复用现有模块。WSL、VMware、macOS、generic Linux 的系统配置和用户 profile 不因 physical 的设置改变。

## 安装前准备

1. 备份 Windows 重要数据与 BitLocker 恢复密钥。若启用了 BitLocker，在更改 Secure Boot 或固件启动设置前暂停保护；确认两个系统都能启动后再恢复保护。不要清空 TPM 或删除固件密钥。参见 [Microsoft BitLocker 操作指南](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/operations-guide)。
2. 使用 NixOS 26.05 的 `x86_64-linux` 安装镜像，以 UEFI 模式启动。当前配置没有 Secure Boot 签名方案，需要关闭 Secure Boot；不要开启 Legacy/CSM 模式。
3. 在固件中保持集成显卡启用，并将主要显示输出设置为 Integrated Graphics/IGD（名称因主板而异）。独显仍可保持硬件启用，供 Windows 使用；不必拔掉独显的显示器。
4. Windows 完全关机。建议关闭快速启动；本方案不挂载 Windows NTFS 分区。以后若要读写它们，必须先确保 Windows 没有休眠、快速启动残留或未解锁的加密卷。
5. 准备独立于这台台式机 Windows 的网络入口，例如另一台电脑或路由器上的代理。进入安装系统后，这台机器上的 Windows 代理已经停止运行。

AMDGPU 会在 initrd 阶段加载；NVIDIA/Nouveau 驱动只在此 NixOS host 中被屏蔽。独显上的显示器不用于 NixOS 桌面，但固件启动画面可能仍出现在那里；屏蔽驱动也不等于独显完全断电。[NixOS AMD GPU 说明](https://wiki.nixos.org/wiki/AMD_GPU)

physical 使用 `time.hardwareClockInLocalTime = true`，与 Windows 默认 RTC 约定一致。如果以后把 Windows 改为 UTC RTC，应同时把此选项改为 `false`，不要混用两套约定。[双系统时间设置](https://wiki.nixos.org/wiki/Dual_Booting_NixOS_and_Windows)

## 先让 Live 安装环境联网

优先连接有线网络；无线网络可通过安装镜像的网络界面或 `nmtui` 配置。后续安装命令在 Live 环境的 root shell 执行：

```bash
sudo -i
test -d /sys/firmware/efi
```

第二条命令必须成功，否则应重新以 UEFI 模式启动安装介质。

以下以**另一台设备**的 HTTP/Mixed 代理 `192.168.1.10:7890` 为例，执行前替换为真实地址。对方需要允许来自安装机的 LAN 连接，并限制防火墙放行范围为可信局域网；不要把无认证代理暴露到公网。

```bash
export http_proxy='http://192.168.1.10:7890'
export https_proxy="$http_proxy"
export no_proxy='localhost,127.0.0.1,::1,.local,mirrors.tuna.tsinghua.edu.cn'
export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy" NO_PROXY="$no_proxy"
curl --fail -I https://github.com
curl --fail --noproxy '*' -I https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/nix-cache-info
```

终端变量不自动改变已经启动的 Nix daemon。为 Live 环境另设临时配置：

```bash
systemctl edit --runtime nix-daemon.service
```

在编辑器的有效区域填写同一个代理地址：

```ini
[Service]
Environment="http_proxy=http://192.168.1.10:7890"
Environment="https_proxy=http://192.168.1.10:7890"
Environment="no_proxy=localhost,127.0.0.1,::1,.local,mirrors.tuna.tsinghua.edu.cn"
```

保存后执行：

```bash
systemctl daemon-reload
systemctl restart nix-daemon.service
systemctl show nix-daemon.service -p Environment
```

没有其他设备可提供代理时，应在进入 Live 环境前准备好 Linux amd64 的 Mihomo 可执行文件、完整配置及所需规则数据，在 Live 中手动启动，然后将上述临时代理地址改为 `127.0.0.1:7890`。不要依赖“先通过不可达网络下载代理，再启动代理”的安装路径。

国内镜像只提供 Nix 二进制缓存，不会替代 GitHub 上的 Flake inputs、zinit 插件或订阅地址；这些连接仍需要可用的代理。仓库沿用现有 `flake.lock`，安装不需要先运行 `nix flake update`。[清华镜像使用说明](https://mirrors.tuna.tsinghua.edu.cn/help/nix-channels/)

## 只分区和挂载空白 SSD

先按容量、型号和序列号识别目标，不能假定它一定是 `/dev/nvme0n1`：

```bash
lsblk -e7 -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS
```

为降低选错盘风险，可在关机后暂时断开其他磁盘，安装完成后再接回。只在已核实的空白 SSD 上用分区工具创建 GPT 分区表及以下两个分区；创建分区表和格式化会清除所选盘的数据。

| 分区 | 建议容量 | 类型和文件系统 | 挂载点 |
|---|---|---|---|
| NixOS ESP | 2 GiB | EFI System Partition，FAT32 | `/boot` |
| NixOS 根分区 | 剩余空间 | Linux filesystem，ext4 | `/` |

`/home` 暂时位于根分区。默认不配置 swap、磁盘加密或休眠。不要格式化、挂载为 `/boot` 或复用 Windows 的 ESP；本方案也不添加 Windows 数据盘的自动挂载。

格式化完成后重新查看 `lsblk -f`，记录**文件系统 UUID，不是 PARTUUID**。将下面两处占位替换为对应 UUID 再执行：

```bash
mount /dev/disk/by-uuid/REPLACE_WITH_NIXOS_ROOT_UUID /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-uuid/REPLACE_WITH_NIXOS_ESP_UUID /mnt/boot
findmnt /mnt
findmnt /mnt/boot
```

确认两个挂载源都属于目标空白 SSD，其中 `/mnt/boot` 是新建的 FAT32 ESP。不要使用 README 中 VMware 的 `by-label` 挂载命令。

## 填写 physical 的硬件信息

将仓库放在目标系统的 `/etc/nixos`。如果该目录已有配置，先检查并备份，不要覆盖；全新安装可执行：

```bash
mkdir -p /mnt/etc
git clone --branch master https://github.com/sweard/nixos-wsl-flake.git /mnt/etc/nixos
cd /mnt/etc/nixos
nixos-generate-config --root /mnt --show-hardware-config
```

最后一条命令仅显示硬件检测结果。对照结果编辑 `hosts/physical/hardware.nix`：

- 将 `REPLACE_WITH_NIXOS_ROOT_UUID` 改为 ext4 根分区的实际 UUID。
- 将 `REPLACE_WITH_NIXOS_ESP_UUID` 改为新 FAT32 ESP 的实际 UUID。
- 按检测结果补充必需的存储控制器模块；保留 AMDGPU 配置和 NVIDIA/Nouveau 黑名单。

不要整份覆盖这个文件，也不要把其他磁盘的自动检测挂载项带进来。单独生成的 `/etc/nixos/hardware-configuration.nix` 不在此 Flake 的 imports 中，不会自动生效。共享的 `native-workstation.nix` 不需要修改。

安装前检查占位已经全部替换：

```bash
if grep -n 'REPLACE_WITH_' hosts/physical/hardware.nix; then
  printf '请先填写 physical 的两个磁盘 UUID，停止安装。\n' >&2
  exit 1
fi
```

## 准备 Mihomo 运行时配置

从订阅服务导出 **Mihomo/Clash 兼容的完整 YAML 配置**，包括节点、代理组与规则。仅有一个订阅 URL 或 Base64 节点列表不能直接作为 `config.yaml`。不要把订阅 URL、节点密码或完整 YAML 加入 Git，也不要用 `builtins.readFile` 或 `environment.etc.*.text` 将它们展开到 Nix store。

将以下监听设置合并到完整配置中，避免重复键；这段不是可单独使用的完整配置：

```yaml
mixed-port: 7890
allow-lan: false
bind-address: 127.0.0.1
mode: rule
tun:
  enable: false
```

若配置还启用了管理 API，只监听回环地址，并设置认证 secret。当前服务不开放 LAN 端口，不启用 TUN 或 DNS 劫持。

首次启动优先使用已内嵌节点、不依赖在线获取 provider 或 GeoIP/GeoSite 的配置。若使用外部规则和地理数据，先准备好对应文件；远程规则下载失败可能让 Mihomo 在监听代理端口前就启动失败。服务的工作目录是 `/var/lib/private/mihomo`，相对规则路径以它为基准，不是 `/etc/mihomo`；需要的本地数据也必须部署到对应位置。

以 root 将准备好的完整配置复制到目标系统，替换下面的来源路径：

```bash
install -d -m 0700 /mnt/etc/mihomo
install -m 0600 /path/to/your/config.yaml /mnt/etc/mihomo/config.yaml
```

NixOS 服务通过 systemd `LoadCredential` 读取该文件。仓库中的 `configFile` 是运行时字符串路径，配置内容不参与构建；缺少此文件会导致首次启动时 Mihomo 失败。参见[仓库锁定版本的 Mihomo 模块](https://github.com/NixOS/nixpkgs/blob/9f78f44a87948854445dae0b6bf82b2e87e4efb5/nixos/modules/services/networking/mihomo.nix)。

## 安装和首次启动

确认仍处于 Live root shell、临时代理可用、挂载正确、UUID 已填写、Mihomo 配置已复制，然后在 `/mnt/etc/nixos` 执行：

```bash
nixos-install --flake .#physical \
  --option substituters 'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10 https://cache.nixos.org/'
nixos-enter --root /mnt
passwd nixos
exit
```

安装过程中还应按提示设置 root 密码。`passwd nixos` 是为桌面普通用户单独设置密码。目标系统的 Mihomo 此时尚未作为目标系统服务运行；安装下载依靠前面准备的 Live 代理。清华镜像优先，官方缓存保留为后备，签名校验不关闭。

安装成功后重启，移除安装介质，用主板启动菜单选择空白 SSD 上的 `Linux Boot Manager` 或对应 NixOS 启动项。进入 Windows 时选原有 `Windows Boot Manager`。systemd-boot 菜单没有 Windows 项是预期行为，不需要开启 `os-prober` 或增加 GRUB。

独立 ESP 避免改写 Windows 的引导文件，但 UEFI NVRAM 和启动顺序仍是整机共享的；安装后默认启动项可能变化，可在固件中重新选择。确认 Windows 与 NixOS 都能启动后再恢复 BitLocker 保护。

## 启动后验证和日常更新

登录用户 `nixos` 后检查磁盘、核显和服务：

```bash
findmnt /
findmnt /boot
bootctl status
lspci -nnk | grep -A3 -E 'VGA|Display|3D'
lsmod | grep -E 'amdgpu|nouveau|nvidia'
systemctl status mihomo greetd --no-pager
pgrep -a niri
```

应看到根分区与 ESP 都来自 NixOS SSD，核显使用 `amdgpu`，没有加载 NVIDIA/Nouveau 模块。独显仍可能出现在 `lspci` 中，这不代表它在驱动桌面。

验证显式代理与直连镜像：

```bash
curl --fail -I -x http://127.0.0.1:7890 https://github.com
curl --fail --noproxy '*' -I https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/nix-cache-info
systemctl show nix-daemon docker -p Environment
```

当前锁定的 NixOS 模块会将 `networking.proxy` 传给会话、[Nix daemon](https://github.com/NixOS/nixpkgs/blob/9f78f44a87948854445dae0b6bf82b2e87e4efb5/nixos/modules/services/system/nix-daemon.nix) 和 [Docker daemon](https://github.com/NixOS/nixpkgs/blob/9f78f44a87948854445dae0b6bf82b2e87e4efb5/nixos/modules/virtualisation/docker.nix)。Docker daemon 拉镜像可使用代理，但容器内部的 `127.0.0.1` 是容器自身，不能照搬宿主地址。SSH、UDP 以及不读取代理变量的 GUI 程序也不会因此自动代理；需要时单独配置，不要把当前方案当成全局 VPN。

在实际 Nix 环境中执行仓库验证与后续重建：

```bash
cd /etc/nixos
scripts/check.sh
sudo nixos-rebuild boot --flake .#physical
```

首次变更驱动或引导配置后重启验证；之后一般配置更新可使用 `sudo nixos-rebuild switch --flake .#physical`。`scripts/check.sh` 检查结构与求值，不代替实机启动、网络和显示验证。

修改 `/etc/mihomo/config.yaml` 后执行 `sudo systemctl restart mihomo`。若代理失败，先运行 `sudo journalctl -u mihomo -b --no-pager` 检查配置与规则数据，再用上述 `curl -x` 单独验证；不要把关闭 Nix 签名校验当成修复方法。向他人提供日志前先遮盖节点、订阅和凭据。启动失败可从 systemd-boot 选择上一代，必要时回到 Live 环境修复；Windows 仍通过主板菜单启动。
