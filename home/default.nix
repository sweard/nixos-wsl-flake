{ userSettings, ... }:
{
  imports = [
    ./modules/development/common.nix
#    ./modules/development/cpp.nix
#    ./modules/development/android.nix
    ./modules/development/rust.nix
    ./modules/development/node.nix
    ./modules/development/python.nix
#    ./modules/development/flutter.nix
    ./modules/shell/zsh.nix
  ];

  home = {
    username = userSettings.username;
    homeDirectory = "/home/${userSettings.username}";
    stateVersion = "26.05";
  };

  xdg.enable = true;
  programs.home-manager.enable = true;
}
