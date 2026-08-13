{
  description = "NixOS-WSL development workstation for Android, Rust, Node, Python and Flutter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zinit 自身由 Flake 锁定；zinit 管理的插件继续使用其原生更新流程。
    zinit = {
      url = "github:zdharma-continuum/zinit";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs
    , nixos-wsl
    , home-manager
    , rust-overlay
    , ...
    }:
    let
      # 首次安装沿用 NixOS-WSL 镜像的默认用户，避免 UID 迁移问题。
      # 若镜像中已经创建了其他用户，只需改这里，并确认该用户已存在。
      userSettings = {
        username = "nixos";
        hostName = "nixos-wsl";
        system = "x86_64-linux";
        timeZone = "Asia/Shanghai";
      };
    in
    {
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        system = userSettings.system;
        specialArgs = {
          inherit inputs userSettings;
        };
        modules = [
          nixos-wsl.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ rust-overlay.overlays.default ];
          }
          ./hosts/wsl
        ];
      };

      formatter.${userSettings.system} = nixpkgs.legacyPackages.${userSettings.system}.nixfmt;
    };
}
