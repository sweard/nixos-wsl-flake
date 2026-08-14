{ pkgs, ... }:
{
  imports = [
    ./base.nix
    ./docker.nix
    ./home-manager.nix
    ./native-desktop.nix
  ];

  # VMware 与物理机统一使用 UEFI，以及安装文档约定的磁盘标签。
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
