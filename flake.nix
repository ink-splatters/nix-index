{
  description = "A files database for nixpkgs";
 
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    pre-commit-hooks={
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    
    # [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]
    systems.url = "github:nix-systems/default";
  };

  nixConfig = {
    extra-substituters = "https://nix-community.cachix.org https://pre-commit-hooks.cachix.org https://aarch64-darwin.cachix.org";
    extra-trusted-public-keys = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc= aarch64-darwin.cachix.org-1:mEz8A1jcJveehs/ZbZUEjXZ65Aukk9bg2kmb0zL9XDA=";
  };


  outputs = { self,  nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system: 
    let
     inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system};

      in 
      with pkgs ; {
        inherit system;

        pre-commit.hooks = {
          nixpkgs-fmt.enable = true;
          rustfmt.enable = true;
          shellcheck.enable = true;
          taplo.enable = true; # toml formatter
          mdformat.enable = true;
          yamllint.enable = true;
        };
      
      packages = {
      pname = "nix-index";
      inherit ((lib.importTOML ./Cargo.toml).package) version;

      src = lib.sourceByRegex self [
        "(examples|src)(/.*)?"
        ''Cargo\.(toml|lock)''
        ''command-not-found\.sh''
      ];

      cargoLock = {
        lockFile = ./Cargo.lock;
      };

      nativeBuildInputs = [ pkg-config ];
      buildInputs = [ openssl curl sqlite ]
        ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Security ];

      postInstall = ''
        substituteInPlace command-not-found.sh \
          --subst-var out
        install -Dm555 command-not-found.sh -t $out/etc/profile.d
      '';

      meta = with lib; {
        description = "A files database for nixpkgs";
        homepage = "https://github.com/nix-community/nix-index";
        license = with licenses; [ bsd3 ];
        maintainers = [ maintainers.bennofs ];
      };
  };

      checks = 
      let
            packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self.packages.${system};
            devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self.devShells.${system};
      in packages // devShells;
      

      devShells = {
        minimal = mkShell {
          name = "nix-index";

          nativeBuildInputs = [
            pkg-config
          ];

          buildInputs = [
            openssl
            sqlite
          ] ++ lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Security
          ];

          env.LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
        };

        default = mkShell {
          name = "nix-index";

          inputsFrom = [ self.devShells.${system}.minimal ];

          nativeBuildInputs = [ rustc cargo clippy rustfmt ];

          env = {
            LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
            RUST_SRC_PATH = rustPlatform.rustLibSrc;
          };
         };
      };

      apps = {
        nix-index = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nix-index";
        };
        nix-locate = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nix-locate";
        };
        default = self.apps.${system}.nix-locate;
      };

      });
}    
