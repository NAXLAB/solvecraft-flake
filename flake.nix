{
  description = "SolveCraft: an open-source parametric 3D CAD application written in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream source. `flake = false` because the repo has no flake.nix of its own.
    # Pinned in flake.lock; `nix flake update solvecraft-src` moves it to the latest commit.
    # To track a release instead: url = "github:bherbruck/solvecraft/v0.1.1";
    solvecraft-src = {
      url = "github:NAXLAB/solvecraft";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, solvecraft-src }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
      mkPackage = pkgs: pkgs.callPackage ./package.nix { src = solvecraft-src; };
    in
    {
      packages = forAllSystems (
        _system: pkgs: rec {
          solvecraft = mkPackage pkgs;
          default = solvecraft;
        }
      );

      apps = forAllSystems (
        system: _pkgs: {
          default = {
            type = "app";
            program = lib.getExe self.packages.${system}.solvecraft;
          };
          # Headless CLI; `solvecraft-cli mcp` starts the MCP server for AI agents.
          cli = {
            type = "app";
            program = "${self.packages.${system}.solvecraft}/bin/solvecraft-cli";
          };
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.solvecraft ];
            packages = with pkgs; [
              rust-analyzer
              clippy
              rustfmt
            ];
            # Lets `cargo run -p solvecraft` find the dlopen'd windowing/GPU libraries.
            LD_LIBRARY_PATH = lib.makeLibraryPath self.packages.${system}.solvecraft.buildInputs;
          };
        }
      );

      # For `nixpkgs.overlays = [ solvecraft.overlays.default ];`, giving `pkgs.solvecraft`.
      overlays.default = final: _prev: {
        solvecraft = mkPackage final;
      };
    };
}
