{
  inputs,
  pkgs,
  ...
}:
let
  niriNoctaliaOverrides = pkgs.writeText "niri-noctalia-overrides.kdl" ''
    // Noctalia settings window.
    window-rule {
        match app-id="dev.noctalia.Noctalia"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 920; }
    }

    debug {
        // Allows notification actions and window activation from Noctalia.
        honor-xdg-activation-with-invalid-serial
    }

    binds {
        Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
        Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
        Alt+Tab { spawn-sh "noctalia msg window-switcher"; }
    }

    // Keep the regular wallpaper stationary while workspaces scroll.
    layer-rule {
        match namespace="^noctalia-wallpaper"
        place-within-backdrop true
    }

    layout {
        background-color "transparent"
    }

  '';

  niriIncludes = pkgs.writeText "niri-noctalia-includes.kdl" ''
    include "${niriNoctaliaOverrides}"
    include optional=true "~/.config/niri/local.kdl"
  '';

  niriConfig = pkgs.runCommand "niri-default-with-noctalia.kdl" { } ''
    cp ${pkgs.niri.doc}/share/doc/niri/default-config.kdl $out

    substituteInPlace $out \
      --replace-fail 'spawn-at-startup "waybar"' 'spawn-at-startup "noctalia"' \
      --replace-fail 'Mod+T hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }' 'Mod+T hotkey-overlay-title="Open a Terminal: ghostty" { spawn "ghostty"; }' \
      --replace-fail 'Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }' 'Mod+D hotkey-overlay-title="Run an Application: Noctalia Launcher" { spawn-sh "noctalia msg panel-toggle launcher"; }' \
      --replace-fail 'Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }' 'Super+Alt+L hotkey-overlay-title="Lock the Screen: Noctalia" { spawn-sh "noctalia msg session lock"; }' \
      --replace-fail 'XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }' 'XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "noctalia msg volume-up"; }' \
      --replace-fail 'XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }' 'XF86AudioLowerVolume allow-when-locked=true { spawn-sh "noctalia msg volume-down"; }' \
      --replace-fail 'XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }' 'XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }' \
      --replace-fail 'XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }' 'XF86AudioMicMute allow-when-locked=true { spawn-sh "noctalia msg mic-mute"; }' \
      --replace-fail 'XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }' 'XF86AudioPlay allow-when-locked=true { spawn-sh "noctalia msg media toggle"; }' \
      --replace-fail 'XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }' 'XF86AudioStop allow-when-locked=true { spawn-sh "noctalia msg media stop"; }' \
      --replace-fail 'XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }' 'XF86AudioPrev allow-when-locked=true { spawn-sh "noctalia msg media previous"; }' \
      --replace-fail 'XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }' 'XF86AudioNext allow-when-locked=true { spawn-sh "noctalia msg media next"; }' \
      --replace-fail 'XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }' 'XF86MonBrightnessUp allow-when-locked=true { spawn-sh "noctalia msg brightness-up"; }' \
      --replace-fail 'XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }' 'XF86MonBrightnessDown allow-when-locked=true { spawn-sh "noctalia msg brightness-down"; }'

    cat ${niriIncludes} >> $out
  '';
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  # Niri 的终端快捷键由本用户配置引用，因此由 Home Manager 安装。
  home.packages = with pkgs; [
    ghostty
    wdisplays
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = false;
    settings = {
      shell.polkit_agent = true;
      idle.behavior.lock.enabled = true;
      idle.behavior.lock.timeout = 600;
      idle.behavior.lock.action = "lock";
      idle.behavior."screen-off".enabled = true;
      idle.behavior."screen-off".timeout = 660;
      idle.behavior."screen-off".action = "screen_off";
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Noctalia";
      };
    };
  };

  xdg.configFile."niri/config.kdl".source = niriConfig;
}
