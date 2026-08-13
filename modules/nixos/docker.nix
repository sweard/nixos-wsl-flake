{ pkgs, userSettings, ... }:
{
  # 使用 NixOS 内的原生 daemon，避免和 Docker Desktop 同时维护两套后端。
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  wsl.docker-desktop.enable = false;
  users.users.${userSettings.username}.extraGroups = [ "docker" ];

  environment.systemPackages = [ pkgs.docker-compose ];
}
