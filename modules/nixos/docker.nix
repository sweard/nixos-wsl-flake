{ pkgs, userSettings, ... }:
{
  # 所有主机使用 NixOS 原生 daemon；WSL 的 Docker Desktop 开关留在 wsl.nix。
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  users.users.${userSettings.username}.extraGroups = [ "docker" ];

  environment.systemPackages = [ pkgs.docker-compose ];
}
