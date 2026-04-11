{ config, lib, pkgs, username, platform, machineType, ... }:

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
  nixpkgs.hostPlatform = platform;

  # Allow unfree packages (needed for Terraform and other tools)
  nixpkgs.config.allowUnfree = true;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Linux builder (runs a NixOS VM for building Linux packages)
  # Only enabled on work machine - to start/stop manually see README.md
  nix.linux-builder.enable = machineType == "work";
  nix.linux-builder.config = lib.mkIf (machineType == "work") {
    virtualisation.diskSize = lib.mkForce (50 * 1024);  # 50 GB
  };
  nix.settings.trusted-users = [ "@admin" username ];
}
