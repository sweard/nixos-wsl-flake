{ pkgs, ... }:
{
  # 4090 的驱动由 Windows 主机管理；此 adapter 暴露 WSLg 所需的图形库。
  wsl.useWindowsDriver = true;

  services.dbus.enable = true;
  programs.dconf.enable = true;

  fonts.packages = [ pkgs.nerd-fonts.meslo-lg ];

  environment.systemPackages = with pkgs; [
    mesa-demos
    vulkan-tools
    wayland-utils
    xdpyinfo
  ];
}
