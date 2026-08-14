{ pkgs, userSettings, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = userSettings.username;
  wsl.docker-desktop.enable = false;
  wsl.startMenuLaunchers = true;
  wsl.wrapBinSh = true;

  # 保留 Windows 可执行文件互操作，但不把整条 Windows PATH 混入 Linux。
  wsl.interop.includePath = false;

  # 为真实 Android 设备提供 usbipd-win 接入能力；默认不自动附加设备。
  wsl.usbip = {
    enable = true;
    autoAttach = [ ];
  };

  wsl.wslConf = {
    automount = {
      enabled = true;
      mountFsTab = false;
      root = "/mnt";
      options = "metadata,uid=1000,gid=100,umask=022,fmask=022";
    };
    boot.systemd = true;
    interop = {
      enabled = true;
      appendWindowsPath = false;
    };
    network = {
      generateHosts = true;
      generateResolvConf = true;
      hostname = userSettings.hostName;
    };
    user.default = userSettings.username;
  };

  environment.systemPackages = with pkgs; [
    usbutils
    pciutils
  ];
}
