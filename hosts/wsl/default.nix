{ ... }:
{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/home-manager.nix
    ../../modules/nixos/wsl.nix
    ../../modules/nixos/wslg.nix
    ../../modules/nixos/docker.nix
    ../../modules/nixos/wsl-proxy.nix
  ];
}
