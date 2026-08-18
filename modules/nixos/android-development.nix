{ userSettings, ... }:
{
  # 这个 adapter 原子化启用 Android 所需的系统许可与用户工具链。
  # 目标 host 只需导入本文件，不应直接从 home/common.nix 启用 Android。
  nixpkgs.config.android_sdk.accept_license = true;

  home-manager.users.${userSettings.username}.imports = [
    ../../home/modules/development/android.nix
  ];
}
