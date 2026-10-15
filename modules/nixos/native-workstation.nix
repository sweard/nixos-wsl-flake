{ pkgs, ... }:
{
  imports = [
    ./base.nix
    ./docker.nix
    ../home-manager.nix
    ./native-desktop.nix
  ];

  # 原生主机共用 UEFI；默认磁盘标签可由 host 覆盖，physical 使用独立 SSD 的 UUID。
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
    };
    efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  services.fstrim.enable = true;

  fonts.packages = [ pkgs.nerd-fonts.meslo-lg ];

  environment.systemPackages = with pkgs; [
    mesa-demos
    pciutils
    usbutils
    vulkan-tools
  ];
}
