{ ... }:
{
  imports = [ ./linux.nix ];

  # 补充 Ubuntu、Arch Linux 等非 NixOS Linux 所需的 XDG 与 profile 集成。
  targets.genericLinux = {
    enable = true;

    # 当前 generic Linux profile 只有 CLI 工具，不创建 GPU 驱动桥接。
    gpu.enable = false;
  };
}
