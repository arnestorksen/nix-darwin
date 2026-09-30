# nixdev -- isolated NixOS guest for agent work. See ~/code/mixos/README.md.
#
# A real file rather than an inlined Nix string: everything here would
# otherwise need '' escaping in front of every ${...}, which has already
# produced two bugs. Syntax-check with `zsh -n darwin/nixdev.zsh`.

# The flake that defines the guest. mixos itself is only its baseline library.
#   - a local directory: copied into the guest (a host path means nothing in
#     there). A subdirectory of a git repo works and may import ../ from it.
#   - anything else (github:you/nixdev, git+https://...): fetched by the guest.
#   - set but empty (MIXOS_FLAKE=): mixos's own fallback guest.
# Either way mixos itself is never fetched: the guest flake's `mixos` input is
# always overridden with a copy of the local clone, MIXOS_REPO.
: "${MIXOS_FLAKE=$HOME/.config/nix-darwin/nixdev}"
: "${MIXOS_REPO:=$HOME/code/mixos}"
: "${MIXOS_CONFIG:=nixdev}"

# Flakes ignore untracked files, and nixdev-apply copies the repo wholesale --
# so a newly created module is silently absent from the build, and the error
# surfaces inside the guest as a confusing "path does not exist". Warn early.
_nixdev_warn_untracked() {
  local dir="$1" label="$2" f
  local -a untracked
  untracked=("${(@f)$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null)}")
  [[ -z ${untracked[1]} ]] && return 0
  print -u2 "nixdev-apply: warning -- untracked files in $label are invisible to Nix:"
  for f in ${untracked[@]}; do
    print -u2 "    $f"
  done
  print -u2 "  run: git -C $dir add -A"
}

# Copy the working tree of MIXOS_REPO into the guest's ~/mixos.
_nixdev_copy_mixos() {
  local guest_home="/home/$USER.guest"
  if [[ ! -d $MIXOS_REPO ]]; then
    print -u2 "nixdev-apply: $MIXOS_REPO not found"
    return 1
  fi
  _nixdev_warn_untracked "$MIXOS_REPO" mixos
  if ! limactl copy -r "$MIXOS_REPO" "nixdev:$guest_home/mixos"; then
    print -u2 "nixdev-apply: failed copying $MIXOS_REPO into the guest"
    return 1
  fi
}

# Start the guest if needed, then open a shell or run a command.
#
# `limactl shell` launches bash whatever the account's login shell is -- it
# sets $SHELL from passwd but does not exec it -- so an interactive session
# lands in bash with no zsh config and no prompt. Checking $SHELL or
# `getent passwd` will not reveal this; only $ZSH_VERSION (or the prompt
# itself) does. So ask the guest what the login shell is and pass it
# explicitly. Only for interactive use: `nixdev -- cmd` is fine in bash and
# does not need the extra round trip.
nixdev() {
  local tmpl="$MIXOS_REPO/lima/nixdev.yaml"
  if limactl list -q 2>/dev/null | grep -qx nixdev; then
    limactl start --tty=false nixdev 2>/dev/null || true
  else
    if [[ ! -f $tmpl ]]; then
      print -u2 "nixdev: $tmpl not found -- clone the mixos repo first"
      return 1
    fi
    limactl start --tty=false --name=nixdev "$tmpl" || return 1
  fi

  if (( $# )); then
    limactl shell nixdev "$@"
    return
  fi

  local login_shell
  login_shell=$(limactl shell nixdev -- getent passwd "$USER" 2>/dev/null | cut -d: -f7)
  if [[ -n $login_shell ]]; then
    limactl shell --shell "$login_shell" nixdev
  else
    limactl shell nixdev
  fi
}

# Push the config into the guest and rebuild it there. The guest builds on its
# own cores, so the host never builds Linux derivations.
nixdev-apply() {
  local guest_home="/home/$USER.guest"
  local target
  local -a override=()

  if [[ -z $MIXOS_FLAKE ]]; then
    _nixdev_copy_mixos || return 1
    target="$guest_home/mixos#$MIXOS_CONFIG"
  elif [[ -d $MIXOS_FLAKE ]]; then
    # Copy the whole repo, not just the flake directory: a subflake's
    # ../imports resolve against the repo, and git+file needs the .git.
    local top sub
    if ! top=$(git -C "$MIXOS_FLAKE" rev-parse --show-toplevel 2>/dev/null); then
      print -u2 "nixdev-apply: $MIXOS_FLAKE is not inside a git repository"
      return 1
    fi
    sub=${MIXOS_FLAKE:A}
    sub=${sub#${top:A}}
    sub=${sub#/}
    _nixdev_warn_untracked "$top" "the guest flake's repo"
    if ! limactl copy -r "$top" "nixdev:$guest_home/personal"; then
      print -u2 "nixdev-apply: failed copying $top into the guest"
      return 1
    fi
    target="git+file://$guest_home/personal${sub:+?dir=$sub}#$MIXOS_CONFIG"
  else
    target="$MIXOS_FLAKE#$MIXOS_CONFIG"
  fi

  # mixos is always the local clone, whatever the guest flake's lock says.
  if [[ -n $MIXOS_FLAKE ]]; then
    _nixdev_copy_mixos || return 1
    override=(--override-input mixos "path:$guest_home/mixos")
  fi

  if ! limactl shell nixdev -- sudo nixos-rebuild switch \
       --flake "$target" "${override[@]}"; then
    print -u2 "nixdev-apply: nixos-rebuild failed; the guest is unchanged"
    return 1
  fi

  # Boots into the generation just built, rather than leaving the guest
  # half-switched. It also settles the transient hostname, which a switch
  # leaves showing the image's "nixos" until the next boot. (It does NOT fix
  # an interactive session landing in bash -- that is limactl shell ignoring
  # the login shell, handled in nixdev() above.)
  print "nixdev-apply: restarting into the new generation..."
  if ! limactl restart --tty=false nixdev; then
    print -u2 "nixdev-apply: the config applied but the restart failed;" \
              "run 'limactl restart nixdev' yourself"
    return 1
  fi
  # Lima's own READY line suggests `limactl shell nixdev`, which lands in
  # bash (see nixdev() above). Point at the function that gets it right.
  print "nixdev-apply: done -- run 'nixdev' to open a shell in the guest"
}

# Throw the sandbox away and rebuild it. By design the guest holds nothing
# worth keeping -- push your work first.
nixdev-reset() {
  print -n 'Delete the nixdev VM and everything in it? [y/N] '
  local reply
  read -r reply
  if [[ $reply != y ]]; then
    print "aborted"
    return 1
  fi
  limactl stop -f nixdev 2>/dev/null
  limactl delete -f nixdev 2>/dev/null
  limactl start --tty=false --name=nixdev "$MIXOS_REPO/lima/nixdev.yaml" || return 1
  nixdev-apply
}
