{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ripgrep
  ];

  programs.git.enable = true;
  programs.home-manager.enable = true;
}
