{ config
, inputs
, lib
, pkgs
, ...
}:
let
  # Flake inputs are immutable source trees without Git metadata. Teach zinit to
  # skip self-update for that layout while leaving plugin updates untouched.
  zinitSource = pkgs.runCommand "zinit-nix-managed" { } ''
    cp -R ${inputs.zinit}/. "$out"
    chmod -R u+w "$out"

    substituteInPlace "$out/zinit-autoload.zsh" \
      --replace-fail \
      '    setopt extendedglob typesetsilent warncreateglobal

    if .zi-check-for-git-changes "$ZINIT[BIN_DIR]"; then' \
      '    setopt extendedglob typesetsilent warncreateglobal

    # BIN_DIR can be an immutable Nix source tree without Git metadata.
    if [[ ! -d "$ZINIT[BIN_DIR]/.git" ]]; then
        (( ! OPTS[opt_-q,--quiet] )) && +zi-log \
            "{info}Zinit is managed by Nix; run {cmd}nix flake update zinit{info} and rebuild.{rst}"
        return 0
    fi

    if .zi-check-for-git-changes "$ZINIT[BIN_DIR]"; then'
  '';

  p10kInstantPrompt = lib.mkOrder 500 ''
    # Powerlevel10k instant prompt；需要尽量靠近 .zshrc 顶部。
    if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
    fi
  '';

  zinitBootstrap = lib.mkOrder 550 ''
    # 代码由 Nix 只读管理；插件等运行数据和缓存保留在可写的 XDG 目录。
    typeset -gA ZINIT
    ZINIT[BIN_DIR]="${config.xdg.dataHome}/zinit/zinit.git"
    ZINIT[HOME_DIR]="${config.xdg.dataHome}/zinit"
    export ZSH_CACHE_DIR="${config.xdg.cacheHome}/zinit"

    source "$ZINIT[BIN_DIR]/zinit.zsh"
    autoload -Uz _zinit
    (( ''${+_comps} )) && _comps[zinit]=_zinit
  '';

  zinitBeforeCompletion = lib.mkOrder 560 ''
    # annex 和补全插件需要先于 Home Manager 的 compinit（order 570）。
    zinit light-mode for \
      zdharma-continuum/zinit-annex-as-monitor \
      zdharma-continuum/zinit-annex-bin-gem-node \
      zdharma-continuum/zinit-annex-patch-dl \
      zdharma-continuum/zinit-annex-rust

    zinit light zsh-users/zsh-completions
  '';

  zinitPlugins = lib.mkOrder 1000 ''
    # 当前常用交互插件；syntax-highlighting 在所有 widget 之后单独加载。
    zinit light-mode for \
      zsh-users/zsh-history-substring-search \
      zsh-users/zsh-autosuggestions

    zinit ice git
    zinit snippet OMZ::plugins/z
    zinit snippet OMZ::plugins/git
    if (( $+commands[brew] )); then
      zinit snippet OMZ::plugins/brew
    fi

    zinit ice depth=1
    zinit light romkatv/powerlevel10k
    [[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
  '';

  localConfiguration = lib.mkOrder 1400 ''
    [[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"
    [[ -r "$HOME/.config/zsh/local.zsh" ]] && source "$HOME/.config/zsh/local.zsh"
  '';

  syntaxHighlighting = lib.mkOrder 1500 ''
    zinit light zsh-users/zsh-syntax-highlighting
  '';
in
{
  xdg.dataFile."zinit/zinit.git".source = zinitSource;

  home.file = {
    ".p10k.zsh".source = ../../dotfiles/p10k.zsh;
    ".config/zsh/local.zsh.example".source = ../../dotfiles/local.zsh.example;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.git-ai/bin"
  ];

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    defaultKeymap = "emacs";

    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 50000;
      save = 50000;
      extended = true;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    setOptions = [
      "AUTO_CD"
      "INTERACTIVE_COMMENTS"
      "NO_BEEP"
    ];

    initContent = lib.mkMerge [
      p10kInstantPrompt
      zinitBootstrap
      zinitBeforeCompletion
      zinitPlugins
      localConfiguration
      syntaxHighlighting
    ];
  };
}
