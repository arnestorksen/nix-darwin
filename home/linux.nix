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
  };

  # Override the shared (Mac-tuned, Retina) font size for this screen.
  programs.ghostty.settings.font-size = 16;
}
