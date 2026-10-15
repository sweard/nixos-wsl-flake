{ ... }:
{
  # 仅由 physical 导入；不要从 base、native-workstation 或 Home Manager 导入。
  services.mihomo = {
    enable = true;
    # 必须保持为字符串路径，不能将含订阅凭据的文件复制进 /nix/store。
    configFile = "/etc/mihomo/config.yaml";
    tunMode = false;
  };

  # NixOS 同时将这些变量应用到用户会话、nix-daemon 和 Docker daemon。
  # Mihomo 自身不继承这套代理，避免代理回环；此配置不是透明代理。
  networking.proxy = {
    default = "http://127.0.0.1:7890";
    noProxy = "localhost,127.0.0.1,::1,.local,mirrors.tuna.tsinghua.edu.cn";
  };

  # 优先使用国内二进制缓存；保留 NixOS 默认官方缓存与签名校验。
  nix.settings.substituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
  ];

  security.sudo.extraConfig = ''
    Defaults env_keep += "http_proxy https_proxy no_proxy"
  '';
}
