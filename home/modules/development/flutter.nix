{ config, pkgs, ... }:
{
  home.packages = [ pkgs.flutter ];

  home.sessionVariables = {
    FLUTTER_ROOT = "${pkgs.flutter}";
    PUB_CACHE = "${config.home.homeDirectory}/.pub-cache";
  };

  home.sessionPath = [ "${config.home.homeDirectory}/.pub-cache/bin" ];
}
