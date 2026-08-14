{ pkgs
, userSettings
, ...
}:
{
  # SDDM 会列出 Plasma 与 Niri；保留 Plasma 作为默认会话。
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.wayland.compositor = "kwin";

  # 保留完整 Plasma 6 桌面与其 X11 兼容会话。
  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = true;

  # Nixpkgs 模块注册 niri-session，并配置 portal、GNOME Keyring 与 swaylock PAM。
  programs.niri.enable = true;

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

  # 上游默认 Niri 配置会调用 Waybar、Fuzzel、Alacritty 与 Swaylock。
  # xwayland-satellite 由 Niri 按需启动，为 X11 应用提供兼容层。
  environment.systemPackages = with pkgs; [
    alacritty
    brightnessctl
    fuzzel
    mako
    networkmanagerapplet
    playerctl
    swaylock
    waybar
    wl-clipboard
    xwayland-satellite
  ];

  # 这些服务只绑定 Niri 会话，避免与 Plasma 自己的通知和认证代理重复。
  systemd.user.services = {
    niri-mako = {
      description = "Mako notification daemon for Niri";
      wantedBy = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.mako}/bin/mako";
        Restart = "on-failure";
      };
    };

    niri-polkit-agent = {
      description = "Polkit authentication agent for Niri";
      wantedBy = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
      };
    };
  };
}
