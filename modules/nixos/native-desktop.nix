{
  inputs,
  pkgs,
  userSettings,
  ...
}:
{
  imports = [
    inputs.noctalia.nixosModules.default
  ];

  services.greetd.enable = true;
  services.greetd.useTextGreeter = true;
  services.greetd.settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.niri}/bin/niri-session";

  # Nixpkgs 注册 niri-session，并配置 portal 与 GNOME Keyring。
  programs.niri.enable = true;

  # Noctalia 的 NixOS 模块只启用其推荐系统服务；包由 Home Manager 唯一安装。
  programs.noctalia = {
    enable = true;
    package = null;
    recommendedServices.enable = true;
  };

  networking.networkmanager.enable = true;
  users.users.${userSettings.username}.extraGroups = [ "networkmanager" ];

  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  security.rtkit.enable = true;
  programs.dconf.enable = true;
  hardware.graphics.enable = true;

  # Noctalia 负责 shell 组件；xwayland-satellite 继续为 X11 应用提供兼容层。
  environment.systemPackages = with pkgs; [
    ghostty
    xwayland-satellite
  ];

}
