# nixdev -- isolated NixOS guest for agent work. See ~/code/mixos/README.md.
#
# A real file rather than an inlined Nix string: everything here would
# otherwise need '' escaping in front of every ${...}, which has already
# produced two bugs. Syntax-check with `zsh -n darwin/nixdev.zsh`.

# The config tree mixos attaches as its `personal` input. A local directory is
# copied into the guest (a host path means nothing in there); anything else --
# github:owner/repo, git+ssh://..., a tarball URL -- is handed to Nix as-is.
# Unset it for the stock anonymous sandbox.
: "${MIXOS_PERSONAL:=$HOME/.config/nix-darwin}"
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
  local -a override=()

  if [[ ! -d $MIXOS_REPO ]]; then
    print -u2 "nixdev-apply: $MIXOS_REPO not found"
    return 1
  fi
  _nixdev_warn_untracked "$MIXOS_REPO" mixos
  if ! limactl copy -r "$MIXOS_REPO" "nixdev:$guest_home/mixos"; then
    print -u2 "nixdev-apply: failed copying $MIXOS_REPO into the guest"
    return 1
  fi

  if [[ -n $MIXOS_PERSONAL ]]; then
    local ref="${MIXOS_PERSONAL#path:}"
    if [[ -d $ref ]]; then
      _nixdev_warn_untracked "$ref" "the personal config"
      if ! limactl copy -r "$ref" "nixdev:$guest_home/personal"; then
        print -u2 "nixdev-apply: failed copying $ref into the guest"
        return 1
      fi
      override=(--override-input personal "path:$guest_home/personal")
    else
      override=(--override-input personal "$MIXOS_PERSONAL")
    fi
  fi

  if ! limactl shell nixdev -- sudo nixos-rebuild switch \
       --flake "$guest_home/mixos#$MIXOS_CONFIG" "${override[@]}"; then
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
  print "nixdev-apply: done"
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
