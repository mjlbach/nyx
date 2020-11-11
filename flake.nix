{
  description = "Eden's home configuration";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "master";
    };

    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      ref = "master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... }@inputs:
    with inputs.nixpkgs.lib;
    let
      forEachSystem = genAttrs [ "x86_64-linux" "aarch64-linux" ];
      pkgsBySystem = forEachSystem (system:
        import inputs.nixpkgs {
          inherit system;
          config = import ./nix/config.nix;
        });

      mkHomeManagerConfiguration = name:
        { system, config }:
        nameValuePair name ({ ... }: {
          imports = [
            (import ./home/aspects)
            (import ./home/profiles)
            (import config)
          ];

          # For compat with nix-shell, nix-build, etc
          home.file."nixpkgs".source = inputs.nixpkgs;
          systemd.user.sessionVariables."NIX_PATH" =
            mkForce "nixpkgs=$HOME/.nixpkgs\${NIX_PATH:+:}$NIX_PATH";

          # Use the same nix config
          xdg.configFile."nixpkgs/config.nix".source = ./nix/config.nix;

          # Re-expose self and nixpkgs as flakes.
          xdg.configFile."nix/registry.json".text = builtins.toJSON {
            version = 2;
            flakes =
              let
                toInput = input:
                  {
                    type = "path";
                    path = input.outPath;
                  } // (
                    filterAttrs
                      (n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash")
                      input
                  );
              in
              [
                {
                  from = { id = "self"; type = "indirect"; };
                  to = toInput inputs.self;
                }
                {
                  from = { id = "nixpkgs"; type = "indirect"; };
                  to = toInput inputs.nixpkgs;
                }
              ];
          };
        });

      mkHomeManagerHostConfiguration = name:
        { system }:
        nameValuePair name (inputs.home-manager.lib.homeManagerConfiguration {
          inherit system;
          configuration = { ... }: {
            imports = [ self.internal.homeManagerConfigurations."${name}" ];
            nixpkgs = {
              config = import ./nix/config.nix;
            };
          };

          # TODO: Use nyx.users to set this depending of the host that was configured
          # username = config.nyx.users.username;
          # homeDirectory = config.nyx.users.homeDirectory;
          username = "eden";
          homeDirectory = "/home/eden";
          pkgs = pkgsBySystem."${system}";
        });

    in {
      internal = {
        # Attribute set of hostnames to home-manager modules with the entire configuration for
        # that host - consumed by the home-manager NixOS module for that host (if it exists)
        # or by `mkHomeManagerHostConfiguration` for home-manager-only hosts.
        homeManagerConfigurations = mapAttrs' mkHomeManagerConfiguration {
          wsl = {
            system = "x86_64-linux";
            config = ./home/hosts/wsl.nix;
          };
        };

        homeConfiguration = forEachSystem (system: {
          wsl = mkHomeManagerHostConfiguration "wsl" { inherit system; };
        });
      };

      devShell = forEachSystem (system:
        with pkgsBySystem."${system}";
        mkShell {
          name = "nyx";
          buildInputs = [
            git-crypt
            gnumake
          ];
        }
      );

      wsl =
        self.internal.homeConfiguration.x86_64-linux.wsl.value.activationPackage;

      defaultPackage.x86_64-linux = self.wsl;
    };
}
