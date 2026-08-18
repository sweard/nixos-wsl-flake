{ userSettings, ... }:
{
  imports = [
    ./modules/cli.nix
    # ./modules/development/cpp.nix
    # ./modules/development/rust.nix
    # ./modules/development/node.nix
    # ./modules/development/python.nix
    # ./modules/development/flutter.nix
    ./modules/shell/zsh.nix
  ];

  home = {
    username = userSettings.username;
    stateVersion = "26.05";
  };

  xdg.enable = true;
  programs.home-manager.enable = true;
}
