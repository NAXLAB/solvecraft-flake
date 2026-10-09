# solvecraft-flake

A Nix flake that packages [SolveCraft](https://github.com/bherbruck/solvecraft), an open-source
parametric 3D CAD application written in Rust (sketches, constraints, extrude/revolve, STEP and
IGES import/export, and an MCP server for AI agents).

The flake tracks upstream's default branch through a flake input. SolveCraft itself is
developed upstream.

## Usage

Run it without installing:

```sh
nix run github:NAXLAB/solvecraft-flake        # the desktop app
nix run github:NAXLAB/solvecraft-flake#cli    # solvecraft-cli (also: `solvecraft-cli mcp`)
```

### Install on NixOS

Add the flake as an input, and make sure your modules receive `inputs` (for example through
`specialArgs = { inherit inputs; };`):

```nix
# flake.nix
inputs.solvecraft = {
  url = "github:NAXLAB/solvecraft-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# any module that takes `inputs` in its arguments
environment.systemPackages = [
  inputs.solvecraft.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Or use the overlay and write `pkgs.solvecraft`:

```nix
nixpkgs.overlays = [ inputs.solvecraft.overlays.default ];
environment.systemPackages = [ pkgs.solvecraft ];
```

Open, Save and Export dialogs go through the XDG desktop portal, so you need a portal backend
that provides a file chooser (for example `xdg-desktop-portal-gnome` or
`xdg-desktop-portal-gtk`) and `hardware.graphics.enable = true` for Vulkan/EGL.

## Updating

Upstream is the `solvecraft-src` input and is pinned in `flake.lock`:

```sh
nix flake update solvecraft-src
nix build
```

The version is read from upstream's `Cargo.toml`, plus the commit date, and dependencies come
from upstream's `Cargo.lock`, so a normal update needs no edits to `package.nix`. The exception
is a new git dependency in `Cargo.lock`: the build will fail asking for an `outputHashes` entry.

## What is in the package

- `solvecraft` (desktop app) and `solvecraft-cli` (headless CLI and MCP server) binaries.
- A desktop entry, written here because upstream ships none, and an icon rendered at build time
  by `solvecraft-cli snapshot`, the same way upstream's AppImage script makes one. If the render
  fails in the build sandbox, the package builds without an icon.
- Runtime libraries (xkbcommon, Wayland, X11, Vulkan, EGL, libdbus) added to the binaries'
  RPATH, because winit, wgpu and rfd load them with `dlopen`.

## Limitations

- aarch64-linux is listed in the flake but untested.

## License

The packaging files in this repository are licensed under the [MIT License](LICENSE).
SolveCraft itself is dual-licensed under MIT or Apache-2.0 by its authors.
