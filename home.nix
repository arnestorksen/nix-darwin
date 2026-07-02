{ config, lib, pkgs, username, hostname, ... }:

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
    # Python
    python3
    uv

    # Fonts
    nerd-fonts.fira-code

    # Shell utilities
    ripgrep
    watch
    tree
    jq
    wget
    curl
    gnugrep
    coreutils

    # Container tools
    colima
    docker
    docker-compose

  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Extra PATH entries
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    DOCKER_HOST = "unix:///Users/ars/.config/colima/default/docker.sock";
    XDG_CONFIG_HOME = "$HOME/.config";
  };

  # Shell configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # oh-my-zsh's kubectl plugin needs this set (and existing) before it's sourced
      export ZSH_CACHE_DIR="$HOME/.cache/zsh"
      mkdir -p "$ZSH_CACHE_DIR/completions"
    '';

    plugins = [
      {
        name = pkgs.zsh-nix-shell.pname;
        src = pkgs.zsh-nix-shell.src;
      }
      {
        name = "kubectl";
        src = "${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/kubectl";
      }
    ];
    initContent = ''
      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # Secrets via macOS Keychain
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(security find-generic-password -a "$USER" -s "github-pat" -w 2>/dev/null)

      bindkey -v
    '';
  };

  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 22;
      background = "#0d0f16";
      window-padding-x = 8;
      window-padding-y = 8;
      scrollback-limit = 10000;
      mouse-hide-while-typing = true;
      keybind = "global:cmd+shift+y=toggle_quick_terminal";
      copy-on-select = "clipboard";
    };
  };

  programs.k9s = {
    enable = true;
  };

  # GPG
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
  };

  # Git — shared settings only; identity is set per-machine in flake.nix
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing.format = null;

    settings = {
      init.defaultBranch = "main";
      core.editor = "nvim";
      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
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
    withRuby = false;
    withPython3 = false;

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

    initLua = ''
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
