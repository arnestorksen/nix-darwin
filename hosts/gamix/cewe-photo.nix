# CEWE Photo (CEWE.no) — the Windows client, run under Wine.
#
# CEWE's Norwegian Linux client is stuck at 6.1.5 (Qt 5.3), which needs
# OpenSSL 1.0 and GStreamer 0.10 — both long gone from nixpkgs. The Windows
# build of the same version ships its own OpenSSL DLLs and runs fine in Wine.
#
# The app itself lives in a dedicated Wine prefix in $HOME (it self-updates,
# so it can't live in the Nix store). On first launch, if it isn't installed
# yet, the official Norwegian web installer is downloaded and started.
{ lib
, writeShellApplication
, makeDesktopItem
, symlinkJoin
, wineWow64Packages
, curl
}:

let
  wine = wineWow64Packages.stable;

  launcher = writeShellApplication {
    name = "cewe-photo";
    runtimeInputs = [ wine curl ];
    text = ''
      export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/cewe"
      # Don't let Wine create its own (broken outside this wrapper) menu
      # entries; skip Mono/Gecko install prompts.
      export WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree,mshtml="
      export WINEDEBUG="''${WINEDEBUG:--all}"

      app_dir="$WINEPREFIX/drive_c/Program Files/CEWE/CEWE.no"

      if [ ! -e "$app_dir/CEWE.no.exe" ]; then
        echo "CEWE.no is not installed yet; downloading the installer..." >&2
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -fL -o "$tmp/setup_CEWE_no.exe" \
          "https://dls.photoprintit.com/api/getClient/28611-nb_NO/hps/setup_CEWE_FOTOBOK.exe/windows"
        wine "$tmp/setup_CEWE_no.exe"
        wineserver -w
        [ -e "$app_dir/CEWE.no.exe" ] || { echo "Installation did not complete." >&2; exit 1; }
      fi

      cd "$app_dir"
      exec wine "$app_dir/CEWE.no.exe" "$@"
    '';
  };

  desktopItem = makeDesktopItem {
    name = "cewe-photo";
    desktopName = "CEWE Fotobok";
    genericName = "Photo book designer";
    exec = "cewe-photo %f";
    icon = "camera-photo";
    categories = [ "Graphics" "Photography" ];
    mimeTypes = [ "application/x-hps-mcf" ];
  };
in
symlinkJoin {
  name = "cewe-photo";
  paths = [ launcher desktopItem ];
  meta = {
    description = "CEWE Photo (Norway) via Wine";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cewe-photo";
  };
}
