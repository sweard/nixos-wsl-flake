{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.nodejs_24
    pkgs.pnpm
  ];

  home.sessionVariables = {
    COREPACK_HOME = "${config.home.homeDirectory}/.cache/corepack";
    PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
  };

  home.sessionPath = [ "${config.home.homeDirectory}/.local/share/pnpm" ];
}
