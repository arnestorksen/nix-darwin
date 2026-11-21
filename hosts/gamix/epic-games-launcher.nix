# Epic's official Linux launcher, repackaged from their .deb.
#
# NOTE: the download URL is unversioned and always serves the latest build, so
# the hash below breaks whenever Epic publishes a new one. To update: run
#   nix-prefetch-url --type sha256 <url> | xargs nix hash convert --hash-algo sha256 --to sri
# and bump `version` to match the .deb's control file.
{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, glib-networking
, webkitgtk_4_1
, gtk3
, libsoup_3
, cairo
, gdk-pixbuf
, glib
, dbus
, libx11
, libayatana-appindicator
}:

stdenv.mkDerivation {
  pname = "epic-games-launcher";
  version = "0.120.0";

  src = fetchurl {
    url = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb";
    hash = "sha256-nVqN4Fj0eqxFgcBmGHnM1LaL1UlDqpTo4J24u2Qd8Qk=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 ];

  buildInputs = [
    stdenv.cc.cc.lib
    webkitgtk_4_1
    gtk3
    libsoup_3
    cairo
    gdk-pixbuf
    glib
    glib-networking # TLS for libsoup/webkit
    dbus
    libx11
    libayatana-appindicator
  ];

  # Loaded via dlopen (tray icon), not in DT_NEEDED.
  runtimeDependencies = [ libayatana-appindicator ];

  unpackPhase = "dpkg-deb -x $src .";

  # 235 MB binary; stripping gains little and takes a long time.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/bin usr/lib usr/share $out/
    runHook postInstall
  '';

  meta = {
    description = "Epic Games Launcher (official Linux build)";
    homepage = "https://store.epicgames.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "EpicGamesLauncher";
  };
}
