{ pkgs, ... }:
{
  home.packages = with pkgs; [
    curl
    wget
    jq
    ripgrep
    fd
    zip
    unzip
    tree
    file
    rsync
    openssh
    gnupg
    gnused
    gawk
    coreutils
    findutils
    less
    which
    tealdeer
    nixfmt
    nil
    fastfetch
    neovim
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      core.autocrlf = "input";
      pull.rebase = false;
    };
  };

  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.fzf.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
