{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  home.username = "arne";
  home.homeDirectory = "/home/arne";
  home.stateVersion = "26.05"; # match your NixOS release, don't change once set

  home.packages = with pkgs; [
    fzf
    htop
    claude-code
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
  };

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
