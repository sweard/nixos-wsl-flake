{ userSettings, ... }:
{
  imports = [ ./common.nix ];

  home.homeDirectory = "/Users/${userSettings.username}";
}
