{
  description = "Analyze bitcoin transactions.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: let
    overlay = prev: final: rec {
      beamPackages = prev.beam.packagesWith prev.beam.interpreters.erlang_27;
      elixir = beamPackages.elixir_1_18;
      erlang = prev.erlang_27;
      hex = beamPackages.hex;
    };

    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    nixpkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [overlay];
      };
    in {
    packages = forAllSystems(system: let
      pkgs = nixpkgsFor system;
      mixNixDeps = pkgs.callPackage ./deps.nix {
        lib = pkgs.lib;
        beamPackages = pkgs.beamPackages;
      };
      in rec {
        default = pkgs.beamPackages.mixRelease {
            pname = "reoxt";
            # Elixir lib source path
            src = ./.;
            version = "0.1.0";

	    # FIXME: once you've addressed the fixme comment above,
	    # uncomment the following line to include mixNixDeps
            inherit mixNixDeps;

	    # Add inputs to the build if you need to
            buildInputs = [ pkgs.elixir ];
          };
      });

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
    in {
      default = pkgs.callPackage ./shell.nix {};
    });
  };
}
