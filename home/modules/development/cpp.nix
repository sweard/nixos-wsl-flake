{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gcc
    clang
    llvm
    lldb
    gdb
    gnumake
    cmake
    ninja
    ccache
    autoconf
    automake
    libtool
  ];
}
