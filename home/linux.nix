{ userSettings, ... }:
{
  imports = [ ./common.nix ];

  home.homeDirectory = "/home/${userSettings.username}";
}
