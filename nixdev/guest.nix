# Plain NixOS configuration layered on mixos's baseline. Paths are relative to
# this file; ../home is the rest of this repo.
{ lib, pkgs, ... }:

{
  time.timeZone = "Europe/Oslo";

  # No uid: lima-init creates the account with the host's uid before any
  # rebuild runs, and NixOS will not renumber an existing user.
  users.users.ars = {
    isNormalUser = true;
    group = "users"; # what lima-init's useradd created it with
    home = "/home/ars.guest"; # Lima's convention; anything else gives two homes
    createHome = true;
    extraGroups = [ "wheel" "docker" ]; # wheel: nixdev-apply rebuilds via sudo
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    git-lfs
    fzf
    tree
    jq
    yq-go
    curl
    wget
    watch
    go-task
    nodejs
    python3
    uv
    go
    docker-compose
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users.ars = {
      imports = [
        # The portable half of this repo: zsh (vi-mode, kubectl plugin),
        # starship, fzf, direnv, and neovim with its LSP/treesitter/telescope
        # setup.
        #
        # Deliberately NOT home/linux.nix, which is specific to the gamix
        # desktop -- KDE, CoreCtrl fan curves, pinentry-qt, and an
        # SSH_AUTH_SOCK pointing at the 1Password agent, which the sandbox
        # must not have.
        ../home/common.nix
      ];

      home.stateVersion = "26.05";

      # A GUI terminal: source-built on Linux and useless headless.
      programs.ghostty.enable = lib.mkForce false;

      programs.git.settings = {
        # common.nix rewrites https://github.com/ to git@github.com:, which is
        # right on a machine with a loaded agent. The sandbox has no SSH
        # access to GitHub by design -- it goes over HTTPS with the App's
        # tokens -- so the rewrite would break every clone and push.
        "url \"git@github.com:\"" = lib.mkForce { };

        user.name = "Arne M. Størksen";
        user.email = "arne.storksen@tv2.no";

        # Signed with the guest's own key, not the host's 1Password one.
        # Register it on GitHub as a signing key only: authentication is the
        # App's job, and a signing key grants no access.
        user.signingKey = "~/.ssh/id_ed25519.pub";
        gpg.format = "ssh";
        commit.gpgSign = true;
      };
    };
  };
}
