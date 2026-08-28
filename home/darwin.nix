{ config, lib, pkgs, username, hostname, ... }:

let
  # commit-msg hook, scoped to ~/code/idp/ via a gitdir includeIf below: blocks
  # commits that don't reference a GitHub issue (#123, owner/repo#123) or a
  # ticket id (TICKET-123), unless the message contains "[no-issue]", is a
  # merge/revert, or is a rebase --autosquash fixup!/squash!/amend! commit.
  requireIssueRefHook = pkgs.writeShellApplication {
    name = "commit-msg";
    runtimeInputs = [ pkgs.git pkgs.gnugrep ];
    text = ''
      msg_file=$1

      # Escape hatch: explicit opt-out marker anywhere in the message.
      if grep -q '\[no-issue\]' "$msg_file"; then
        exit 0
      fi

      # Exempt in-progress merges/cherry-picks. commit-msg only gets the message
      # file path as an argument, so this can't be detected from argv -- check
      # the repo state files git itself uses for the duration of the operation.
      merge_head=$(git rev-parse --git-path MERGE_HEAD)
      cherry_pick_head=$(git rev-parse --git-path CHERRY_PICK_HEAD)
      if [ -f "$merge_head" ] || [ -f "$cherry_pick_head" ]; then
        exit 0
      fi

      first_line=$(head -n1 "$msg_file")
      case "$first_line" in
        "Merge "* | "Revert "* | "fixup! "* | "squash! "* | "amend! "*)
          exit 0
          ;;
      esac

      # Strip comment lines (default commentChar '#') before searching -- same
      # convention `git commit --cleanup=strip` uses to decide what is content.
      content=$(grep -v '^#' "$msg_file" || true)

      if printf '%s\n' "$content" | grep -Eq '#[0-9]+|[A-Z][A-Z0-9]+-[0-9]+'; then
        exit 0
      fi

      {
        echo "commit-msg: no issue/ticket reference found in commit message."
        echo
        echo "Commits under ~/code/idp/ must reference a GitHub issue or ticket, e.g.:"
        echo "  #123                    issue in this repo"
        echo "  owner/repo#123          cross-repo issue"
        echo "  TICKET-123              Jira-style ticket id"
        echo
        echo "Fix:      amend the message (git commit --amend) to add a reference."
        echo "Override: add \"[no-issue]\" anywhere in the message (rare, on purpose)."
        echo "Bypass:   git commit --no-verify (skips this and all other hooks)."
      } >&2
      exit 1
    '';
  };

  # prepare-commit-msg companion hook: when the current branch follows
  # `gh issue develop`'s default naming (`<number>-<slug>`, as created by the
  # `gi` zsh function in nix-work-env), pre-fill the commit message with a
  # "Refs: #<number>" trailer so the commit-msg hook above is satisfied with
  # zero typing.
  requirePrepareCommitMsgHook = pkgs.writeShellApplication {
    name = "prepare-commit-msg";
    runtimeInputs = [ pkgs.git pkgs.gnugrep pkgs.gawk pkgs.coreutils pkgs.gnused ];
    text = ''
      msg_file=$1
      commit_source=''${2:-}

      # Skip merge commits and `git merge --squash` -- git generates their
      # subject/body itself and it shouldn't be second-guessed here.
      case "$commit_source" in
        merge | squash)
          exit 0
          ;;
        *)
          ;;
      esac

      # Already has a reference (e.g. `git commit --amend` on a commit that
      # already passed commit-msg, or the user typed one themselves) --
      # don't insert a second one. Same stripping/regex as commit-msg.
      content=$(grep -v '^#' "$msg_file" || true)
      if printf '%s\n' "$content" | grep -Eq '#[0-9]+|[A-Z][A-Z0-9]+-[0-9]+'; then
        exit 0
      fi

      # Only act on branches following `gh issue develop`'s default naming,
      # e.g. `123-fix-login-bug` (created by the `gi` shell function).
      branch=$(git branch --show-current)
      if [ -z "$branch" ]; then
        exit 0
      fi

      issue=""
      if [[ "$branch" =~ ^([0-9]+)- ]]; then
        issue=''${BASH_REMATCH[1]}
      fi
      if [ -z "$issue" ]; then
        exit 0
      fi

      # If this branch was created via `gia` for an issue in a *different*
      # repo, branch.<name>.issueRepo records which one, so the reference
      # points at the right issue instead of "#<issue>" in this repo.
      issue_repo=$(git config --get "branch.$branch.issueRepo" 2>/dev/null || true)

      # Default to "Refs" (link only, no auto-close) -- put "[closes]"
      # anywhere in the message to opt this specific commit into "Closes",
      # which auto-closes the issue once this commit lands on the default
      # branch. The marker itself is stripped from the final message.
      keyword="Refs"
      if grep -q '\[closes\]' "$msg_file"; then
        keyword="Closes"
        tmp_stripped=$(mktemp)
        sed -E 's/\[closes\]//g' "$msg_file" > "$tmp_stripped"
        mv "$tmp_stripped" "$msg_file"
      fi

      if [ -n "$issue_repo" ]; then
        trailer="$keyword: $issue_repo#$issue"
      else
        trailer="$keyword: #$issue"
      fi

      # Insert the trailer right after the subject line, or make it the
      # subject line itself if that line is currently empty -- the
      # `git commit` editor case, where the file is a blank first line
      # followed by a large block of `#` comment/instruction lines that
      # must stay at the bottom, untouched.
      tmp_file=$(mktemp)
      awk -v trailer="$trailer" '
        NR == 1 {
          if ($0 == "") {
            print trailer
          } else {
            print $0
            print trailer
          }
          next
        }
        { print }
        END {
          if (NR == 0) {
            print trailer
          }
        }
      ' "$msg_file" > "$tmp_file"
      mv "$tmp_file" "$msg_file"
    '';
  };

  # Combine both hooks into one directory -- core.hooksPath must point at
  # exactly one directory.
  idpGitHooks = pkgs.linkFarm "idp-git-hooks" {
    "commit-msg" = "${requireIssueRefHook}/bin/commit-msg";
    "prepare-commit-msg" = "${requirePrepareCommitMsgHook}/bin/prepare-commit-msg";
  };

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
  # resizes/centers it via System
  # Events (Ghostty's scripting dictionary has no window size/position
  # controls). There's a brief visible flash at the default size/position
  # before the resize lands -- seems inherent to how a newly created window
  # first renders, not something a delay fixes (tested with delays from 0 to
  # 300ms; all show the same flash) -- accepted as a minor cosmetic
  # papercut rather than something worth fighting further.
  ghosttyOpenTabSwitcher = pkgs.writeShellApplication {
    name = "ghostty-open-tab-switcher";
    text = ''
      osascript -l JavaScript - <<'JXA'
      ObjC.import("AppKit");

      function run() {
        const gh = Application("Ghostty");
        const cfg = gh.newSurfaceConfiguration({});
        cfg.command = "${ghosttyTabSwitcher}/bin/ghostty-switch-tab";
        cfg.waitAfterCommand = false;
        gh.newWindow({ withConfiguration: cfg });

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

  # GPG
  programs.gpg.enable = true;

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
      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };
  };

  # Require an issue/ticket reference in commit messages for repos under
  # ~/code/idp/ (everything else, including this dotfiles repo, is unaffected).
  programs.git.includes = [
    {
      condition = "gitdir:~/code/idp/";
      contents.core.hooksPath = "${idpGitHooks}";
    }
  ];

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

}
