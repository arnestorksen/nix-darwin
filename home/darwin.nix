{ config, lib, pkgs, username, hostname, ... }:

let
  # fzf-powered tab switcher for Ghostty, triggered by Cmd+Shift+O via skhd
  # (see hosts/*/configuration.nix -- Ghostty's own keybind system can't run an
  # arbitrary external command without typing it into a focused terminal
  # first). Runs in its own small popup window (spawned by
  # ghosttyOpenTabSwitcher) rather
  # than the current tab, so it feels like a floating overlay instead of
  # taking over whatever pane you're in. Uses Ghostty 1.3+'s native
  # AppleScript dictionary (application -> windows -> tabs -> terminals, see
  # Ghostty.app/Contents/Resources/Ghostty.sdef) via `osascript -l
  # JavaScript` to list tabs (excluding its own popup window), enumerate,
  # select, and activate.
  #
  # Ghostty's own "wait after command" setting -- which is supposed to
  # auto-close the surface once its command exits -- turned out unreliable
  # in testing: the exact same command/config sometimes closed the window on
  # exit and sometimes left it sitting at "Process exited. Press any key to
  # close." with no discernible pattern. So instead of depending on that,
  # this closes its own window explicitly via an EXIT trap, which is
  # deterministic regardless of that bug.
  ghosttyTabSwitcher = pkgs.writeShellApplication {
    name = "ghostty-switch-tab";
    runtimeInputs = [ pkgs.fzf ];
    text = ''
      self_id=$(osascript -l JavaScript -e 'Application("Ghostty").frontWindow().id()')

      close_self() {
        osascript -l JavaScript - "$self_id" <<'JXA'
      function run(argv) {
        const gh = Application("Ghostty");
        for (const w of gh.windows()) {
          if (w.id() === argv[0]) {
            gh.closeWindow(w);
            break;
          }
        }
      }
      JXA
      }
      trap close_self EXIT

      tabs=$(osascript -l JavaScript - "$self_id" <<'JXA'
      function run(argv) {
        const selfId = argv[0];
        const gh = Application("Ghostty");
        const wins = gh.windows();
        const out = [];
        for (let w = 0; w < wins.length; w++) {
          if (wins[w].id() === selfId) continue;
          const tabs = wins[w].tabs();
          for (let t = 0; t < tabs.length; t++) {
            const marker = tabs[t].selected() ? "*" : " ";
            out.push([marker, tabs[t].name(), w + 1, t + 1].join("\t"));
          }
        }
        return out.join("\n");
      }
      JXA
      )

      if [ -z "$tabs" ]; then
        exit 0
      fi

      selection=$(printf '%s\n' "$tabs" | fzf --delimiter='\t' --with-nth=1,2 \
        --prompt='tab> ' --height=~100% --reverse)

      if [ -z "$selection" ]; then
        exit 0
      fi

      win=$(printf '%s' "$selection" | cut -f3)
      tab=$(printf '%s' "$selection" | cut -f4)

      osascript -l JavaScript - "$win" "$tab" <<'JXA'
      function run(argv) {
        const win = Number(argv[0]);
        const tab = Number(argv[1]);
        const gh = Application("Ghostty");
        const target = gh.windows()[win - 1];
        gh.selectTab(target.tabs()[tab - 1]);
        gh.activateWindow(target);
      }
      JXA
    '';
  };

  # Launcher invoked by skhd's Cmd+Shift+O binding (see hosts/*/configuration.nix):
  # spawns a popup window running ghosttyTabSwitcher, then immediately
  # resizes/centers it via System Events (Ghostty's scripting dictionary has
  # no window size/position controls). There's a brief visible flash at the
  # default size/position before the resize lands -- seems inherent to how a
  # newly created window first renders, not something a delay fixes (tested
  # with delays from 0 to 300ms; all showed the same flash).
  #
  # A short delay before the resize call *does* matter for a different
  # reason, though: without it, the resize occasionally silently no-ops
  # (window stays at the default frame) -- a race between window creation
  # and the new window actually showing up in System Events' accessibility
  # tree, most noticeable when triggered via skhd rather than run directly.
  ghosttyOpenTabSwitcher = pkgs.writeShellApplication {
    name = "ghostty-open-tab-switcher";
    text = ''
      osascript -l JavaScript - <<'JXA'
      ObjC.import("AppKit");
      ObjC.import("unistd");

      function run() {
        const gh = Application("Ghostty");
        const cfg = gh.newSurfaceConfiguration({});
        cfg.command = "${ghosttyTabSwitcher}/bin/ghostty-switch-tab";
        cfg.waitAfterCommand = false;
        gh.newWindow({ withConfiguration: cfg });

        $.usleep(150000);

        const se = Application("System Events");
        const w = se.processes.byName("ghostty").windows()[0];

        const screen = $.NSScreen.mainScreen.frame;
        const width = 720;
        const height = 440;
        w.position = [
          screen.origin.x + (screen.size.width - width) / 2,
          screen.origin.y + screen.size.height * 0.22,
        ];
        w.size = [width, height];
      }
      JXA
    '';
  };
in

{
  imports = [ ./common.nix ];

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

    # Version control -- gh is shared (not work-only) because the
    # gi/gia/gd/gpb functions in git-issue-workflow.nix depend on it.
    gh

    # Shell utilities
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
    container

    # Kubernetes / Crossplane
    crossplane-cli

    # Task runner
    go-task

    # Ghostty tab switcher (fzf over open tabs, see keybind below)
    ghosttyTabSwitcher
    ghosttyOpenTabSwitcher

  ];

  # Extra PATH entries
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    DOCKER_HOST = "unix:///Users/${username}/.config/colima/default/docker.sock";
    XDG_CONFIG_HOME = "$HOME/.config";
  };

  # Shell configuration -- portable bits (completion, kubectl plugin, vi mode)
  # come from home/common.nix; only the macOS-specific pieces are added here.
  programs.zsh = {
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    initContent = ''
      # Secrets via macOS Keychain -- to set/rotate, see README.md#updating-the-github-pat
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(security find-generic-password -a "$USER" -s "github-pat" -w 2>/dev/null)
    '';
  };

  programs.k9s = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
  };

  # Git — shared settings only; identity is set per-machine in flake.nix
  programs.git = {
    lfs.enable = true;
    signing.format = null;

    settings = {
      init.defaultBranch = "main";
      core.editor = "nvim";
    };
  };


  # Direnv integration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Workaround for nix-direnv 3.2.0 (nix-community/nix-direnv#786):
  # _nix_refresh_gcroots touches .direnv/flake-profile-*, which also matches the
  # watched flake-profile-<hash>.rc, so every load invalidates every other
  # shell's cache and two terminals in one repo reload each other forever.
  # Upstream's fix (PR #790) drops the refresh entirely; nothing here needs it
  # (no nh, no mtime-based gcroot cleaner), so make it a no-op.
  # Sourced after home-manager's hm-nix-direnv.sh thanks to the zz- prefix; kept
  # out of direnvrc because nix-direnv watches that file itself.
  # Remove once nixpkgs ships a nix-direnv with #790 merged.
  home.file.".config/direnv/lib/zz-nix-direnv-no-gcroot-touch.sh".text = ''
    _nix_refresh_gcroots() { :; }
  '';

  # FZF integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

}
