{ pkgs, ... }:
{
  home.packages = [
    pkgs.python3
    pkgs.python3Packages.virtualenv
    pkgs.pipx
  ];
}
