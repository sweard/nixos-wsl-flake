{ inputs
, userSettings
, ...
}:
{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/nixos/wsl.nix
    ../../modules/nixos/wslg.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/proxy.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs userSettings;
    };
    users.${userSettings.username} = import ../../home;
  };
}
