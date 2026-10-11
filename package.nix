{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  copyDesktopItems,
  makeWrapper,
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
    makeWrapper
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
      name = "ai.storyteller.solvecraft";
      desktopName = "SolveCraft";
      comment = "Parametric 3D CAD";
      exec = "solvecraft %f";
      icon = "ai.storyteller.solvecraft";
      startupWMClass = "ai.storyteller.solvecraft";
      categories = [ "Graphics" "Engineering" ];
      mimeTypes = [ "model/step" ];
    })
  ];

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    for b in solvecraft solvecraft-cli; do
      patchelf --add-rpath ${lib.makeLibraryPath finalAttrs.buildInputs} $out/bin/$b
    done

    # Upstream forces X11 whenever DISPLAY is set, and compositors using xwayland-satellite
    # (niri) always set it, which breaks the app-drawn title bar (maximize/restore/resize).
    # In a Wayland session, use native Wayland instead. Set SOLVECRAFT_X11=1 to keep upstream's
    # behaviour. Pure X11 sessions have no WAYLAND_DISPLAY and are unaffected.
    wrapProgram $out/bin/solvecraft \
      --run 'if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$SOLVECRAFT_X11" ]; then export SOLVECRAFT_WAYLAND=1; fi'

    # Render the app icon with the CLI (it draws the logo in code), in the sizes the hicolor theme
    # looks for. The icon is named after the app id so Wayland compositors match it to the window.
    for s in 16 24 32 48 64 128 256 512; do
      dir=$out/share/icons/hicolor/$s"x"$s/apps
      mkdir -p $dir
      $out/bin/solvecraft-cli icon --size $s --out $dir/ai.storyteller.solvecraft.png >/dev/null
    done
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
