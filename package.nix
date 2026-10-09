{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  copyDesktopItems,
  makeDesktopItem,
  libxkbcommon,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  vulkan-loader,
  libGL,
  dbus,
  # The upstream source tree, supplied by the flake (the `solvecraft-src` input).
  src,
}:

let
  # Everything below is derived from the source, so updating the flake input needs no edits here.
  workspaceVersion = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
  # Flake inputs expose lastModifiedDate as YYYYMMDDHHMMSS.
  d = src.lastModifiedDate or "19700101000000";
  date = "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "solvecraft";
  # The flake input follows upstream's default branch, so the commit date marks the snapshot.
  version = "${workspaceVersion}-unstable-${date}";

  inherit src;

  # While Cargo.lock has only crates.io and in-tree path sources (the vendored truck-* patches
  # under vendor/ are path dependencies), no hashes ever need updating. If upstream adds a git
  # dependency, Nix will error and ask for an `outputHashes` entry for it.
  cargoLock.lockFile = "${src}/Cargo.lock";

  # Build only the desktop app and the CLI (which also hosts the MCP server), as upstream's
  # release workflow does. The workspace also contains a wasm app and xtask.
  cargoBuildFlags = [
    "--package"
    "solvecraft"
    "--package"
    "solvecraft-cli"
  ];

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  # winit, wgpu and rfd load these with dlopen at runtime, so they are not ELF NEEDED entries;
  # they are added to the RPATH in postFixup. rfd's xdg-portal backend dlopens libdbus-1.so.3:
  # without it, Open/Save/Export dialogs silently fail to appear.
  buildInputs = [
    libxkbcommon # also provides libxkbcommon-x11
    wayland
    libx11
    libxcb
    libxcursor
    libxi
    vulkan-loader
    libGL # libEGL fallback when Vulkan is unavailable
    dbus
  ];

  # The test suite includes GPU/UI scenario tests that don't work in the sandbox.
  doCheck = false;

  # Upstream ships no desktop file; this mirrors the one its AppImage script writes.
  desktopItems = [
    (makeDesktopItem {
      name = "solvecraft";
      desktopName = "SolveCraft";
      comment = "Parametric 3D CAD";
      exec = "solvecraft %f";
      icon = "solvecraft";
      categories = [
        "Graphics"
        "Engineering"
      ];
      mimeTypes = [ "model/step" ];
    })
  ];

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''

    for b in solvecraft solvecraft-cli; do
      patchelf --add-rpath ${lib.makeLibraryPath finalAttrs.buildInputs} $out/bin/$b
    done

    # Upstream commits no icon: its AppImage script renders one with SolveCraft itself from the
    # bracket example. Do the same, and carry on without an icon if the headless render fails
    # in the sandbox.

    export HOME=$TMPDIR
    
    if $out/bin/solvecraft-cli snapshot ${src}/examples/bracket.json \
         --out $TMPDIR/solvecraft.png --width 256 --height 256 >/dev/null 2>&1; then
      install -Dm644 $TMPDIR/solvecraft.png \
        $out/share/icons/hicolor/256x256/apps/solvecraft.png
    else
      echo "warning: could not render an icon; installing without one" >&2
    fi
  '';

  meta = {
    description = "Open-source parametric 3D CAD application written in Rust";
    homepage = "https://github.com/bherbruck/solvecraft";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "solvecraft";
    platforms = lib.platforms.linux;
  };
})
