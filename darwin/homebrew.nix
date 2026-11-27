{ ... }:

# Shared by both Macs. Homebrew casks are a nix-darwin (system) option, so
# this can't live in home-manager (home/*.nix). Homebrew itself is installed
# separately at /opt/homebrew; nix-darwin only manages what's listed here.
{
  homebrew = {
    enable = true;
    casks = [
      "vivaldi"
    ];
  };
}
