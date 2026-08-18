{ userSettings, ... }:
{
  # 迁移本机已有的 /opt/homebrew：删除原 Homebrew 代码仓库，保留已安装包，
  # 再由 nix-homebrew 提供受 Nix 管理的 Homebrew 实现。首次启用前先按 README 备份。
  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    user = userSettings.username;
    autoMigrate = true;
  };

  # nix-homebrew 负责安装，nix-darwin 的 homebrew 模块负责声明包。
  # 初次接入时不自动升级或清理，避免意外改变现有 Homebrew 环境。
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
  };
}
