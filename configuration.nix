{ config, lib, pkgs, username, platform, ... }:

{
  # System packages kept minimal - user packages go in home-manager
  environment.systemPackages = [ ];

  # Define user for Home Manager
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Required by nix-darwin for any user-scoped option (e.g. services.skhd
  # below) since system activation runs as root, not the interactive user.
  system.primaryUser = username;

  # Set Git commit hash for darwin-rebuild
  system.configurationRevision = null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;

  # Allow unfree packages (needed for Terraform and other tools)
  nixpkgs.config.allowUnfree = true;

  nix.settings.trusted-users = [ "@admin" username ];

  # Global hotkey daemon. Currently used for just one binding: Cmd+Shift+O
  # opens the Ghostty tab-switcher popup (ghosttyOpenTabSwitcher in
  # home.nix) from anywhere, without typing into whatever terminal happens
  # to be focused. Ghostty's own keybind system has no "run an external
  # command" action -- its only bridge to external scripts is "text:", which
  # types into the focused surface, so triggering this without touching a
  # terminal at all needs something outside Ghostty entirely.
  #
  # References the stable ~/.nix-profile/bin symlink (home-manager keeps it
  # pointed at the current generation) rather than the derivation directly,
  # since home.nix's home-manager module and this system module are
  # evaluated separately.
  #
  # Requires a one-time manual grant: System Settings -> Privacy & Security
  # -> Accessibility -> add skhd. Without it, the hotkey silently does
  # nothing.
  services.skhd.enable = true;
  services.skhd.skhdConfig = ''
    cmd + shift - o : /Users/${username}/.nix-profile/bin/ghostty-open-tab-switcher
  '';
}
