{ pkgs, sidraPkg, ... }:

{
  imports = [ ./common.nix ];

  home.username = "arne";
  home.homeDirectory = "/home/arne";
  home.stateVersion = "26.05"; # match your NixOS release, don't change once set

  home.packages = with pkgs; [
    fzf
    htop
    claude-code
    sidraPkg # Apple Music desktop client, from the sidra flake input (not in nixpkgs)
  ];

  programs.git.settings = {
    user.name = "Arne M. Størksen";
    user.email = "arne.storksen@gmail.com";
    user.signingKey = "D923C0D7FA86BA69"; # same personal key as arne-mac
    commit.gpgSign = true;
    gpg.format = "openpgp";
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt; # fits the KDE Plasma desktop
    # Cache the passphrase for as long as the agent is alive (effectively
    # once per login/reboot), instead of the ~2h default -- avoids retyping
    # it on every signed commit while still requiring it once per session.
    defaultCacheTtl = 34560000;
    maxCacheTtl = 34560000;
    # Needed for gpg-preset-passphrase (see the `gpg-unlock` shell function
    # below), which loads the passphrase from 1Password instead of pinentry.
    extraConfig = "allow-preset-passphrase";
  };

  # Preloads the GPG signing key's passphrase into gpg-agent's cache straight
  # from 1Password (op:// requires the desktop app running and unlocked, same
  # as the manual `op read | gpg --import` step in README.md). Run once per
  # login; after that, signed commits don't need pinentry until the agent
  # restarts (see the extended cache TTL above).
  programs.zsh.initContent = ''
    gpg-unlock() {
      local libexecdir passphrase grip
      libexecdir=$(gpgconf --list-dirs libexecdir)
      passphrase=$(op read "op://Private/GPG signing key/password") || return 1
      gpg --with-colons --with-keygrip --list-secret-keys D923C0D7FA86BA69 \
        | awk -F: '$1 == "grp" { print $10 }' \
        | while IFS= read -r grip; do
            printf '%s\n' "$passphrase" \
              | "$libexecdir/gpg-preset-passphrase" --preset "$grip"
          done
    }
  '';

  # 1Password's SSH agent socket (its Linux app uses the same path as macOS).
  # Requires: SSH Agent enabled in 1Password's own settings, and the key
  # added under its SSH Keys section -- see README.md#1password-ssh--gpg-setup.
  home.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";

  # Override the shared (Mac-tuned, Retina) font size for this screen.
  programs.ghostty.settings.font-size = 16;

  # macOS-style `caffeinate`: blocks sleep/idle-suspend for as long as it
  # runs. Ctrl-C (or close the terminal) to let normal sleep resume.
  programs.zsh.shellAliases.caffeinate =
    "systemd-inhibit --what=sleep:idle --why=caffeinate --mode=block sleep infinity";

  # Autostart CoreCtrl (GPU fan curve control) minimized to the system tray,
  # so the fan curve set there keeps applying without opening it manually.
  xdg.configFile."autostart/corectrl.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=CoreCtrl
    Exec=${pkgs.corectrl}/bin/corectrl --minimize-systray
    Icon=corectrl
    X-GNOME-Autostart-enabled=true
  '';
}
