{ inputs
, userSettings
, ...
}:
{
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
