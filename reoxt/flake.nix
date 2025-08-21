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

          buildInputs = [pkgs.elixir pkgs.esbuild pkgs.tailwindcss];

          # Explicitly declare tailwind and esbuild binary paths (don't let Mix fetch them)
          preConfigure = ''
            substituteInPlace config/config.exs \
              --replace "config :tailwind," "config :tailwind, path: \"${pkgs.tailwindcss}/bin/tailwindcss\","\
              --replace "config :esbuild," "config :esbuild, path: \"${pkgs.esbuild}/bin/esbuild\", "
          '';
      };});

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
    in {
      default = pkgs.callPackage ./shell.nix {};
    });
  };
}
