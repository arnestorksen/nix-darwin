{ config, lib, pkgs, username, hostname, machineType, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "24.11";

  # Packages that should be installed to the user profile
  home.packages = with pkgs; [
    # Version control
    gh  # GitHub CLI

    # Python
    python3
    uv

    # Shell utilities
    ripgrep
    watch
    tree
    jq
    yq-go
    wget
    curl
    gnugrep
    coreutils
    sops

    # Container tools
    colima
    docker
    docker-compose

    # Tools for running mpc servers
    nodejs

    # Kubernetes tools
    kubectl
    kustomize
    kubelogin
    kubectx  # includes kubens
    kubernetes-helm
    kind
    dapr-cli

  ] ++ (if machineType == "work" then [
    # Work-specific packages
    awscli2
    amazon-ecr-credential-helper
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    argocd
    cilium-cli
    hubble
  ] else []);

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Extra PATH entries
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Shell configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "kubectl" ];
    };

    initContent = ''
      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # Secrets via macOS Keychain
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(security find-generic-password -a "$USER" -s "github-pat" -w 2>/dev/null)
    '';
  };

  programs.k9s = {
    enable = true;
  };

  # Sync secrets from 1Password to macOS Keychain at login
  # To trigger manually: launchctl kickstart -k gui/$UID/sync-secrets
  launchd.agents.sync-secrets = {
    enable = true;
    config = {
      Label = "sync-secrets";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          PAT=$(/opt/homebrew/bin/op read "op://Private/Github/PAT" 2>/dev/null)
          [ -n "$PAT" ] && /usr/bin/security add-generic-password -U -a "$USER" -s "github-pat" -w "$PAT"
        ''
      ];
      RunAtLoad = true;
    };
  };


  # GPG
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
  };

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user.name = "Arne Mellesmo Størksen";
      user.email = if machineType == "work" then "arne.storksen@tv2.no" else "arne.storksen@gmail.com";
      user.signingKey = if machineType == "work"
        then "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqRo+OElcjXCy4JqZyE2gSDd1wUiDx+u5xs1XYLDAxt"
        else "D923C0D7FA86BA69";
      commit.gpgSign = true;
      gpg.format = if machineType == "work" then "ssh" else "openpgp";
      init.defaultBranch = "main";
      core.editor = "nvim";
      url."git@github.com:".insteadOf = "https://github.com/";
    } // lib.optionalAttrs (machineType == "work") {
      "gpg \"ssh\"" = {
        program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
      };
    };

    includes = lib.optionals (machineType == "work") [
      {
        condition = "gitdir:~/code/private/";
        contents = {
          user.email = "arne.storksen@gmail.com";
          user.signingKey = "D923C0D7FA86BA69";
          gpg.format = "openpgp";
        };
      }
      {
        condition = "gitdir:~/.config/nix-darwin/";
        contents = {
          user.email = "arne.storksen@gmail.com";
          user.signingKey = "D923C0D7FA86BA69";
          gpg.format = "openpgp";
        };
      }
    ];
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # You can customize the configuration here later
    # settings = {
    #   add_newline = false;
    #   character = {
    #     success_symbol = "[➜](bold green)";
    #     error_symbol = "[➜](bold red)";
    #   };
    # };
  };

  # Direnv integration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # FZF integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Neovim configuration files
  home.file.".config/nvim/lua" = {
    source = ./nvim/lua;
    recursive = true;
  };

  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      # Color scheme
      tokyonight-nvim

      # LSP and completion
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      luasnip
      cmp_luasnip

      # Treesitter
      (nvim-treesitter.withPlugins (p: [
        p.go
        p.terraform
        p.hcl
        p.yaml
        p.lua
        p.vim
        p.bash
        p.python
        p.json
        p.markdown
      ]))

      # Telescope
      telescope-nvim
      telescope-fzf-native-nvim
      plenary-nvim

      # File explorer
      nvim-tree-lua
      nvim-web-devicons

      # Status line
      lualine-nvim

      # Git integration
      gitsigns-nvim

      # Quality of life
      comment-nvim
      nvim-autopairs
      which-key-nvim
    ];

    extraPackages = with pkgs; [
      # LSP servers
      gopls
      terraform-ls
      yaml-language-server
      bash-language-server

      # Formatters and linters
      gofumpt
      gotools
      terraform
      shfmt
      shellcheck
    ];

    extraLuaConfig = ''
      -- Load configuration modules
      require('config.settings')
      require('config.lsp')
      require('config.completion')
      require('config.treesitter')
      require('config.telescope')
      require('config.plugins')
    '';
  };
}
