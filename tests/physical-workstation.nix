# Apply to the flake's nixosConfigurations to check merged module values.
hosts:
let
  physical = hosts.physical.config;
  vmware = hosts.vmware.config;
  otherHosts = [
    hosts.wsl.config
    vmware
  ];
  proxy = "http://127.0.0.1:7890";
  mirror = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10";
  noProxy = physical.networking.proxy.noProxy;
  checks = {
    igpuOnly =
      physical.services.xserver.videoDrivers == [ "amdgpu" ]
      && builtins.elem "amdgpu" physical.boot.initrd.kernelModules
      && builtins.all (driver: builtins.elem driver physical.boot.blacklistedKernelModules) [
        "nouveau"
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
        "nvidia_uvm"
      ];
    independentEsp =
      physical.boot.loader.systemd-boot.enable
      && !physical.boot.loader.grub.enable
      && physical.boot.loader.efi.efiSysMountPoint == "/boot"
      && physical.boot.loader.systemd-boot.configurationLimit == 10
      && physical.boot.loader.timeout == 5
      && physical.fileSystems."/".fsType == "ext4"
      && physical.fileSystems."/boot".fsType == "vfat"
      && builtins.all (
        mountPoint:
        builtins.match "/dev/disk/by-uuid/.+" physical.fileSystems.${mountPoint}.device != null
      ) [
        "/"
        "/boot"
      ];
    windowsClock = physical.time.hardwareClockInLocalTime;
    runtimeMihomo =
      physical.services.mihomo.enable
      && physical.services.mihomo.configFile == "/etc/mihomo/config.yaml"
      && !physical.services.mihomo.tunMode;
    proxyConsumers = builtins.all (
      env:
      env.http_proxy == proxy
      && env.https_proxy == proxy
      && env.no_proxy == noProxy
    ) [
      physical.environment.sessionVariables
      physical.systemd.services.nix-daemon.environment
      physical.systemd.services.docker.environment
    ];
    mihomoDoesNotProxyItself =
      !(physical.systemd.services.mihomo.environment ? http_proxy)
      && !(physical.systemd.services.mihomo.environment ? https_proxy);
    mirrorWithOfficialFallback =
      builtins.elem mirror physical.nix.settings.substituters
      && builtins.elem "https://cache.nixos.org/" physical.nix.settings.substituters
      && physical.nix.settings.require-sigs
      && builtins.elem "mirrors.tuna.tsinghua.edu.cn" (
        builtins.filter builtins.isString (builtins.split "," noProxy)
      );
    otherHostsUnchanged = builtins.all (
      host:
      !host.services.mihomo.enable
      && host.networking.proxy.default == null
      && !(builtins.elem mirror host.nix.settings.substituters)
    ) otherHosts;
    vmwareKeepsDiskLabels =
      vmware.fileSystems."/".device == "/dev/disk/by-label/nixos"
      && vmware.fileSystems."/boot".device == "/dev/disk/by-label/boot"
      && vmware.boot.loader.systemd-boot.configurationLimit == 20
      && !vmware.time.hardwareClockInLocalTime;
  };
in
builtins.mapAttrs (
  name: passed: if passed then true else throw "physical regression failed: ${name}"
) checks
