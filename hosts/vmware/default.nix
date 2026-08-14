{ pkgs, ... }:
{
  imports = [
    ../../modules/nixos/native-workstation.nix
    ./hardware.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # 允许通过 VMware NAT 网络从宿主机维护虚拟机。
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}
