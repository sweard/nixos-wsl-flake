{
  description = "Multi-platform NixOS, nix-darwin, and Home Manager environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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
      nixpkgs-darwin,
      nix-darwin,
      nix-homebrew,
      nixos-wsl,
      home-manager,
      ...
    }:
    let
      nixosUserSettings = {
        username = "nixos";
        timeZone = "Asia/Shanghai";
      };

      darwinUserSettings = {
        username = "sbwoan";
        hostName = "Jeffs-MacBook-Pro";
        system = "aarch64-darwin";
        timeZone = "Asia/Shanghai";
      };

      genericLinuxUserSettings = {
        username = "jeff";
        system = "aarch64-linux";
        timeZone = "Asia/Shanghai";
      };

      mkNixosSystem =
        {
          system,
          hostName,
          homeProfile,
          modules,
        }:
        let
          userSettings = nixosUserSettings // {
            inherit hostName system;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs userSettings homeProfile;
          };
          modules = [
            home-manager.nixosModules.home-manager
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        wsl = mkNixosSystem {
          system = "x86_64-linux";
          hostName = "nixos-wsl";
          homeProfile = ./home/linux.nix;
          modules = [
            nixos-wsl.nixosModules.default
            ./hosts/wsl
          ];
        };

        vmware = mkNixosSystem {
          system = "aarch64-linux";
          hostName = "nixos-vmware";
          homeProfile = ./home/native-desktop.nix;
          modules = [ ./hosts/vmware ];
        };

        physical = mkNixosSystem {
          system = "x86_64-linux";
          hostName = "nixos-physical";
          homeProfile = ./home/native-desktop.nix;
          modules = [ ./hosts/physical ];
        };
      };

      darwinConfigurations."Jeffs-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          userSettings = darwinUserSettings;
          homeProfile = ./home/darwin.nix;
        };
        modules = [
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/macbook
        ];
      };

      # 非 NixOS Linux 只复用用户工具与 dotfiles；系统服务继续由宿主发行版管理。
      homeConfigurations."jeff-aarch64-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = genericLinuxUserSettings.system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          userSettings = genericLinuxUserSettings;
        };
        modules = [ ./home/generic-linux.nix ];
      };

      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt;
        aarch64-darwin = nixpkgs-darwin.legacyPackages.aarch64-darwin.nixfmt;
      };
    };
}
