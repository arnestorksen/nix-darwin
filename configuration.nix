{ config, pkgs, username, ... }:

{
  # System packages kept minimal - user packages go in home-manager
  environment.systemPackages = [ ];

  # Define user for Home Manager
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Set Git commit hash for darwin-rebuild
  system.configurationRevision = null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow unfree packages (needed for Terraform and other tools)
  nixpkgs.config.allowUnfree = true;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";
}
