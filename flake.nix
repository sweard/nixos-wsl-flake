{
  description = "Multi-host NixOS development workstation for WSL, VMware and physical hardware";

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

    noctalia = {
      url = "github:noctalia-dev/noctalia";
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
    inputs@{
      nixpkgs,
      nixos-wsl,
      home-manager,
      rust-overlay,
      ...
    }:
    let
      commonUserSettings = {
        username = "nixos";
        timeZone = "Asia/Shanghai";
      };

      mkSystem =
        {
          system,
          hostName,
          modules,
        }:
        let
          userSettings = commonUserSettings // {
            inherit hostName system;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs userSettings;
          };
          modules = [
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [ rust-overlay.overlays.default ];
            }
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        wsl = mkSystem {
          system = "x86_64-linux";
          hostName = "nixos-wsl";
          modules = [
            nixos-wsl.nixosModules.default
            ./hosts/wsl
          ];
        };

        vmware = mkSystem {
          system = "aarch64-linux";
          hostName = "nixos-vmware";
          modules = [ ./hosts/vmware ];
        };

        physical = mkSystem {
          system = "x86_64-linux";
          hostName = "nixos-physical";
          modules = [ ./hosts/physical ];
        };
      };

      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt;
      };
    };
}
