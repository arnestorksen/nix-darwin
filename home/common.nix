{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ripgrep
  ];

  programs.git.enable = true;
  programs.home-manager.enable = true;

  # Shell configuration -- platform-specific bits (Homebrew, macOS Keychain)
  # are layered on top in home/darwin.nix.
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    profileExtra = ''
      # oh-my-zsh's kubectl plugin needs this set (and existing) before it's sourced
      export ZSH_CACHE_DIR="$HOME/.cache/zsh"
      mkdir -p "$ZSH_CACHE_DIR/completions"
    '';

    plugins = [
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

      bindkey -v
    '';
  };

  # Ghostty terminal. ghostty-bin (prebuilt) only exists for aarch64-darwin
  # in nixpkgs; everywhere else falls back to the source build.
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.system == "aarch64-darwin"
      then pkgs.ghostty-bin
      else pkgs.ghostty;
    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 22;
      background = "#0d0f16";
      window-padding-x = 8;
      window-padding-y = 8;
      scrollback-limit = 10000;
      mouse-hide-while-typing = true;
      keybind = [
        "global:cmd+shift+y=toggle_quick_terminal"
      ];
      copy-on-select = "clipboard";
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = ''
        $directory$git_branch$git_state$git_status$kubernetes$nix_shell$cmd_duration$status
        $character'';

      kubernetes = {
        disabled = false;
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        style = "bold blue";
      };

      status = {
        disabled = false;
        style = "bold red";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # Neovim configuration files
  home.file.".config/nvim/lua" = {
    source = ../nvim/lua;
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
      diffview-nvim

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
