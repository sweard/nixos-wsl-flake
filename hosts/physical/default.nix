{ lib, ... }:
{
  imports = [
    ../../modules/nixos/native-workstation.nix
    ../../modules/nixos/native-proxy.nix
    ./hardware.nix
  ];

  # NixOS 使用自己的 SSD 和 ESP；Windows 从主板 UEFI 启动菜单进入。
  boot.loader = {
    efi.efiSysMountPoint = "/boot";
    timeout = 5;
    systemd-boot.configurationLimit = lib.mkForce 10;
  };

  # 与 Windows 默认的本地时间 RTC 保持一致，仅影响此物理机。
  time.hardwareClockInLocalTime = true;
}
