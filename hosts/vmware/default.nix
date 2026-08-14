{ pkgs, ... }:
{
  imports = [
    ../../modules/nixos/native-workstation.nix
    ./hardware.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # 避免 Plasma 恢复 DrKonqi 等只应由 systemd 临时启动的辅助进程。
  environment.etc."xdg/ksmserverrc".text = ''
    [General]
    loginMode=emptySession
  '';

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
