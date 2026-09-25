{ lib, pkgs, ... }:

# GitHub issue workflow: the `gi`/`gia`/`gd`/`gpb` shell functions and the git
# hooks they exist to satisfy, kept together because they're one feature --
# the hooks require and pre-fill an issue reference in commit messages under
# ~/code/idp/, and the functions create the `<number>-<slug>` branches those
# hooks key off. Shared by both machines (imported from flake.nix, alongside
# ../home/darwin.nix); `gh`, `jq` and `fzf` come from ../home/darwin.nix.
#
# See README.md -- "GitHub issue workflow" for the user-facing walkthrough.

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
  # `gi` zsh function in programs.zsh.initContent below), pre-fill the commit
  # message with a
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
in
{
  # Require an issue/ticket reference in commit messages for repos under
  # ~/code/idp/ (everything else, including this dotfiles repo, is unaffected).
  programs.git.includes = [
    {
      condition = "gitdir:~/code/idp/";
      contents.core.hooksPath = "${idpGitHooks}";
    }
  ];

  # mkAfter just to keep these below ../home/darwin.nix's initContent (nix-daemon
  # sourcing, PAT export, `bindkey -v`); position is otherwise irrelevant,
  # since nothing here runs at definition time.
  programs.zsh.initContent = lib.mkAfter ''
    # Build a short `<number>-<slug>` branch name from an issue number/title,
    # capped at the first 5 words of the title (gh's own default slug uses
    # the full title, which gets unwieldy for long issue titles). This is
    # the naming convention requirePrepareCommitMsgHook (above) and the
    # starship module key off.
    _gi_branch_name() {
      local number=$1 title=$2 slug
      slug=$(
        printf '%s' "$title" \
          | tr '[:upper:]' '[:lower:]' \
          | sed -E 's/[^a-z0-9]+/ /g' \
          | awk '{ n = (NF < 5 ? NF : 5); out = $1; for (i = 2; i <= n; i++) out = out "-" $i; print out }'
      )
      printf '%s-%s' "$number" "$slug"
    }

    # Shared by `gi`/`gia`: pick an open issue from $1 (owner/repo) via fzf,
    # and create+checkout a linked branch for it in $2 (owner/repo) -- $1
    # and $2 are the same repo for `gi`, different for `gia`. Only records
    # branch.<name>.issueRepo (which prepare-commit-msg uses to build a
    # cross-repo "owner/repo#N" reference) when they actually differ, so a
    # same-repo pick -- via `gi`, or via `gia` picking the current repo --
    # keeps using the short "#N" form.
    _gi_develop() {
      local issue_repo=$1 branch_repo=$2
      local issues_json selection issue_number title branch_name actual_branch tmpdir
      local jq_list_filter list_cmd

      tmpdir=$(mktemp -d)

      {
        # One batched call (title + body) instead of a separate `gh issue
        # view` per issue on every fzf cursor move -- that per-move network
        # round-trip was the actual source of preview sluggishness, not the
        # list fetch itself. Each issue's body is written to its own file
        # so the default preview is a fast local `cat`, no network at all.
        # --limit: gh issue list defaults to 30, silently truncating repos
        # with more open issues than that.
        issues_json=$(gh issue list --repo "$issue_repo" --state open --limit 1000 --json number,title,body) || return 1

        # Process substitution (not `producer | while ...`) so the loop
        # runs directly in this shell rather than as the last stage of a
        # piped subshell -- avoids a zsh job-control quirk where the
        # subshelled loop could leak stray output (seen in practice as a
        # bare "n=<value>" line printed once).
        local n
        while IFS= read -r issue_line; do
          n=$(printf '%s' "$issue_line" | jq -r '.number')
          printf '%s' "$issue_line" | jq -r '"# " + .title + "\n\n" + (.body // "(no description)")' > "$tmpdir/$n"
        done < <(printf '%s' "$issues_json" | jq -c '.[]')

        # Shared between the initial candidate list and ctrl-n's reload,
        # so both produce the exact same tab-delimited format.
        jq_list_filter='.[] | "\(.number)\t#\(.number)  \(.title)\t\(.title)"'
        list_cmd="gh issue list --repo $issue_repo --state open --limit 1000 --json number,title --jq '$jq_list_filter'"

        # ctrl-n uses --editor (not the interactive default) -- gh's own
        # interactive title/body prompts can choke on terminal
        # shell-integration escape sequences (seen in practice as "could
        # not prompt: unexpected escape sequence"); a plain $EDITOR
        # session doesn't have that problem.
        selection=$(
          printf '%s' "$issues_json" | jq -r "$jq_list_filter" \
          | fzf --delimiter=$'\t' --with-nth=2 \
                --preview "cat '$tmpdir'/{1} 2>/dev/null || echo '(no description)'" \
                --preview-window=right:60% \
                --header 'ctrl-n: new issue  |  ctrl-o: full view  |  ctrl-r: fast preview' \
                --bind "ctrl-o:preview(gh issue view {1} --repo $issue_repo)" \
                --bind "ctrl-r:preview(cat '$tmpdir'/{1} 2>/dev/null || echo '(no description)')" \
                --bind "ctrl-n:execute(gh issue create --repo $issue_repo --editor)+reload($list_cmd)+first"
        ) || return 1

        if [ -z "$selection" ]; then
          return 1
        fi

        issue_number=$(printf '%s' "$selection" | cut -f1)
        title=$(printf '%s' "$selection" | cut -f3)
        branch_name=$(_gi_branch_name "$issue_number" "$title")

        gh issue develop "$issue_number" --repo "$issue_repo" --branch-repo "$branch_repo" \
          --name "$branch_name" --checkout || return 1

        if [ "$issue_repo" != "$branch_repo" ]; then
          actual_branch=$(git branch --show-current)
          git config branch."$actual_branch".issueRepo "$issue_repo"
        fi
      } always {
        rm -rf "$tmpdir"
      }
    }

    # Look up an open GitHub issue for the current repo via fzf, and check out
    # a linked branch for it.
    gi() {
      local current_slug
      current_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || return 1
      _gi_develop "$current_slug" "$current_slug"
    }

    # Like `gi`, but for issues filed in a different repo under ~/code/idp/ than
    # the one you're currently in: pick that repo, pick one of its open issues,
    # then create a linked branch for it *in the current repo* (via
    # --branch-repo) and check it out here.
    gia() {
      local repo_name repo_dir repo_slug current_slug

      repo_name=$(find ~/code/idp -mindepth 1 -maxdepth 1 -type d -exec basename {} \; \
        | sort | fzf --prompt="repo> ") || return 1
      if [ -z "$repo_name" ]; then
        return 1
      fi
      repo_dir="$HOME/code/idp/$repo_name"

      repo_slug=$(cd "$repo_dir" && gh repo view --json nameWithOwner --jq .nameWithOwner) || return 1
      current_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || return 1

      _gi_develop "$repo_slug" "$current_slug"
    }

    # Conclude work on the current issue branch without a PR: get whatever
    # work is here committed (staged changes -- opens $EDITOR if no
    # message is given, like a normal git commit; an empty commit if the
    # branch has nothing unique yet), then make sure the branch tip's
    # trailer says "Closes" instead of the usual "Refs" -- reusing the
    # exact same upgrade whether that tip is the commit just made or one
    # that was already there -- then rebase onto the default branch,
    # fast-forward merge, push, and delete the branch (local + remote).
    # Unstaged/untracked changes are left exactly as they were: stashed
    # before the risky operations (rebase, checkout) and restored at the
    # very end. Since the branch itself gets deleted, that "end" is on the
    # default branch, not back on the branch (unlike `gpb`, which keeps
    # the branch alive and restores onto it).
    gd() {
      local branch default_branch stashed

      branch=$(git branch --show-current)
      if [ -z "$branch" ]; then
        echo "gd: not on a branch" >&2
        return 1
      fi

      if [[ ! "$branch" =~ ^[0-9]+- ]]; then
        echo "gd: branch '$branch' doesn't look like an issue branch (expected <number>-<slug>)" >&2
        return 1
      fi

      default_branch=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name) || return 1
      git fetch origin "$default_branch" || return 1

      # 1. Get the actual work committed, however the user wants to
      # describe it. No mention of "[closes]" here at all --
      # prepare-commit-msg inserts its normal "Refs:" trailer same as any
      # other commit on this branch; step 2 below upgrades it.
      if ! git diff --cached --quiet; then
        if [ -n "''${1:-}" ]; then
          git commit -m "$1" || return 1
        else
          git commit || return 1
        fi
      elif git merge-base --is-ancestor HEAD "origin/$default_branch"; then
        # No commit unique to this branch yet, so there's nothing safe to
        # amend (HEAD is also on $default_branch) -- fall back to an
        # empty commit.
        if [ -n "''${1:-}" ]; then
          git commit --allow-empty -m "$1" || return 1
        else
          git commit --allow-empty || return 1
        fi
      fi
      # (else: nothing staged, but a real commit already exists -- step 2
      # below handles upgrading its trailer; nothing new to describe.)

      # 2. Whatever ended up on the tip -- freshly written just now, or
      # already there from before -- make sure it says Closes, not Refs,
      # since gd always concludes/closes the issue. prepare-commit-msg
      # only inserts a trailer when the message doesn't already have a
      # reference, so we upgrade "Refs:" to "Closes:" ourselves here
      # rather than relying on "[closes]" -- except when there's no
      # existing reference at all (e.g. a hookless commit), where
      # appending "[closes]" and re-running through amend still works.
      local old_msg
      old_msg=$(git log -1 --format=%B)
      if printf '%s' "$old_msg" | grep -q '^Closes:'; then
        : # already closing; nothing to change
      elif printf '%s' "$old_msg" | grep -q '^Refs:'; then
        git commit --amend -m "$(printf '%s' "$old_msg" | sed 's/^Refs:/Closes:/')" || return 1
      else
        git commit --amend -m "$old_msg [closes]" || return 1
      fi

      # Anything left uncommitted at this point is unstaged/untracked --
      # stash it (git status --porcelain catches untracked files too,
      # unlike `git diff`) so the rebase/checkout below don't choke on a
      # dirty tree, and restore it once we're done.
      stashed=0
      if [ -n "$(git status --porcelain)" ]; then
        git stash push --include-untracked --message "gd autostash" || return 1
        stashed=1
      fi

      {
        git rebase "origin/$default_branch" || return 1

        git checkout "$default_branch" || return 1
        git merge --ff-only "origin/$default_branch" || return 1
        git merge --ff-only "$branch" || return 1
        git push origin "$default_branch" || return 1

        # -D (not -d): the closing commit we just added locally was never
        # pushed to the branch's own remote ref (only merged into
        # $default_branch), so git's safe-delete would refuse it even
        # though the preceding --ff-only merge already proved it's fully
        # merged.
        git branch -D "$branch" || echo "gd: warning: could not delete local branch $branch" >&2
        git push origin --delete "$branch" || echo "gd: warning: could not delete remote branch $branch" >&2
      } always {
        if [ "$stashed" -eq 1 ]; then
          git stash pop || echo "gd: warning: could not restore stashed changes -- run 'git stash pop' manually" >&2
        fi
      }
    }

    # Merge the current branch's committed work into the default branch and
    # push it -- for trunk-based workflows where local branches just organize
    # work/track an issue, not for review. Unlike `gd`, this doesn't close the
    # issue or delete the branch. Staged changes get folded into whatever
    # commit is already unique to this branch (like a rebase would preserve
    # it, keeping its message unless you pass a new one) rather than piling
    # up separate "WIP" commits; only a branch with no unique commit yet gets
    # a genuinely new one (defaulting to "WIP" if no message is given). Then:
    # rebase, fast-forward merge into the default branch, push it, then
    # return to the branch and push it too (force-with-lease, since the
    # rebase may have rewritten its already-pushed history) so you can keep
    # working on it.
    gpb() {
      local branch default_branch stashed

      branch=$(git branch --show-current)
      if [ -z "$branch" ]; then
        echo "gpb: not on a branch" >&2
        return 1
      fi

      default_branch=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name) || return 1

      if [ "$branch" = "$default_branch" ]; then
        echo "gpb: already on $default_branch" >&2
        return 1
      fi

      git fetch origin "$default_branch" || return 1

      if ! git diff --cached --quiet; then
        if git merge-base --is-ancestor HEAD "origin/$default_branch"; then
          # No commit unique to this branch yet -- nothing to fold into.
          if [ -n "''${1:-}" ]; then
            git commit -m "$1" || return 1
          else
            git commit || return 1
          fi
        else
          if [ -n "''${1:-}" ]; then
            git commit --amend -m "$1" || return 1
          else
            git commit --amend || return 1
          fi
        fi
      fi

      # Stash around the *whole* sequence, not just the rebase: gpb is
      # meant to be run often while actively working, so uncommitted
      # changes are the common case. Rebase alone would tolerate that
      # with --autostash, but the later `checkout $default_branch` would
      # still refuse to run on a dirty tree -- so stash before any of it
      # and restore at the very end regardless of how this exits.
      # `git status --porcelain` (not `git diff`) so untracked-only
      # changes aren't missed.
      stashed=0
      if [ -n "$(git status --porcelain)" ]; then
        git stash push --include-untracked --message "gpb autostash" || return 1
        stashed=1
      fi

      {
        git rebase "origin/$default_branch" || return 1

        git checkout "$default_branch" || return 1
        git merge --ff-only "origin/$default_branch" || return 1
        git merge --ff-only "$branch" || return 1
        git push origin "$default_branch" || return 1

        git checkout "$branch" || return 1
        git push --force-with-lease origin "$branch" || return 1
      } always {
        if [ "$stashed" -eq 1 ]; then
          # Back on the original branch first, regardless of where the
          # try-block above stopped, so the stash has the best chance of
          # applying cleanly (it was taken from this branch's state).
          git checkout "$branch" 2>/dev/null
          git stash pop || echo "gpb: warning: could not restore stashed changes -- run 'git stash pop' manually" >&2
        fi
      }
    }
  '';
}
