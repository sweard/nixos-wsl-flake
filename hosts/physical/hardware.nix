{
  config,
  lib,
  ...
}:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];

  # NixOS 只使用 7950X 核显；不加载 RTX 4090 的驱动。
  # 这不会禁用 Windows 中的独显，也不保证独显完全断电。
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  # 安装前必须替换为目标 SSD 的文件系统 UUID（不是 PARTUUID）。
  # 仅覆盖 physical，VMware 继续使用 native-workstation 的标签约定。
  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-uuid/REPLACE_WITH_NIXOS_ROOT_UUID";
    "/boot".device = lib.mkForce "/dev/disk/by-uuid/REPLACE_WITH_NIXOS_ESP_UUID";
  };
}
