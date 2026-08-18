{ userSettings, ... }:
{
  nixpkgs = {
    hostPlatform = userSettings.system;
    config.allowUnfree = true;
  };

  networking.hostName = userSettings.hostName;
  time.timeZone = userSettings.timeZone;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.zsh.enable = true;

  system = {
    primaryUser = userSettings.username;
    stateVersion = 6;
  };

  users.users.${userSettings.username} = {
    name = userSettings.username;
    home = "/Users/${userSettings.username}";
  };
}
