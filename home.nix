{ config, pkgs, username, ... }:

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
    git
    git-lfs
    gh  # GitHub CLI

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
    antidote

    # Cloud tools
    awscli2

    # Container tools
    colima
    docker
    docker-compose

    # Kubernetes tools
    kubectl
    kustomize
    kubelogin
    kubectx  # includes kubens
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Shell configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    # Add nix to PATH and setup antidote
    initContent = ''
      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # Antidote plugin manager
      source ${pkgs.antidote}/share/antidote/antidote.zsh
      antidote load
    '';
  };

  programs.k9s = {
    enable = true;
  };

  # Antidote plugins file
  home.file.".zsh_plugins.txt".text = ''
    # oh-my-zsh plugins via antidote
    ohmyzsh/ohmyzsh path:plugins/kubectl
    ohmyzsh/ohmyzsh path:plugins/git

    # You can add more plugins here, for example:
    # zsh-users/zsh-autosuggestions
    # zsh-users/zsh-syntax-highlighting
  '';

  # Git configuration (you can customize this later)
  programs.git = {
    enable = true;
    settings.user = {
    	name = "Arne Størksen";
    	email = if username == "ars" then "arne.storksen@tv2.no" else "arne.storksen@gmail.com";
    };
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
