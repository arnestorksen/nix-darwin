# Sandbox instance settings for the mixos NixOS guest (~/code/mixos).
#
# mixos imports this file as a NixOS module from whatever tree its `personal`
# input points at, so nothing about this machine lives in that repo. Attach it
# with MIXOS_PERSONAL (see darwin/nixdev.zsh):
#
#   MIXOS_PERSONAL=$HOME/.config/nix-darwin nixdev-apply
#
# Paths below are relative to this file, i.e. to this repo.
{ ... }:

{
  mixos = {
    hostName = "nixdev";
    timeZone = "Europe/Oslo";

    # No uid: lima-init creates the account with the host's uid before any
    # rebuild runs, and NixOS will not renumber an existing user.
    user.name = "ars";

    personal.homeModules = [
      # The portable half of this repo: zsh (vi-mode, kubectl plugin),
      # starship, fzf, direnv, and neovim with its LSP/treesitter/telescope
      # setup.
      #
      # Deliberately NOT home/linux.nix, which is specific to the gamix
      # desktop -- KDE, CoreCtrl fan curves, pinentry-qt, and an SSH_AUTH_SOCK
      # pointing at the 1Password agent, which the sandbox must not have.
      ./home/common.nix

      # Sandbox-specific deltas.
      (
        { lib, ... }:
        {
          # A GUI terminal: source-built on Linux and useless headless.
          programs.ghostty.enable = lib.mkForce false;

          programs.git.settings = {
            # common.nix rewrites https://github.com/ to git@github.com:,
            # which is right on a machine with a loaded agent. The sandbox has
            # none by design, so the rewrite breaks credential-free cloning of
            # public repos before the guest's own key exists.
            "url \"git@github.com:\"" = lib.mkForce { };

            user.name = "Arne M. Størksen";
            user.email = "arne.storksen@tv2.no";

            # Signed with the guest's own key, not the host's 1Password one.
            # Register that key on GitHub twice: as an authentication key and
            # as a signing key.
            user.signingKey = "~/.ssh/id_ed25519.pub";
            gpg.format = "ssh";
            commit.gpgSign = true;
          };
        }
      )
    ];
  };
}
