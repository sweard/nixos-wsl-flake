{ ... }:
{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/nixos/home-manager.nix
    ../../modules/nixos/wsl.nix
    ../../modules/nixos/wslg.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/proxy.nix
  ];
}
