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
  limactl shell nixdev "$@"
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
  limactl copy -r "$MIXOS_REPO" "nixdev:$guest_home/mixos" || return 1

  if [[ -n $MIXOS_PERSONAL ]]; then
    local ref="${MIXOS_PERSONAL#path:}"
    if [[ -d $ref ]]; then
      _nixdev_warn_untracked "$ref" "the personal config"
      limactl copy -r "$ref" "nixdev:$guest_home/personal" || return 1
      override=(--override-input personal "path:$guest_home/personal")
    else
      override=(--override-input personal "$MIXOS_PERSONAL")
    fi
  fi

  limactl shell nixdev -- sudo nixos-rebuild switch \
    --flake "$guest_home/mixos#$MIXOS_CONFIG" "${override[@]}" || return 1

  # Not optional. A switch leaves sshd serving the account's previous login
  # shell, so every session lands in bash and the prompt looks broken; the
  # transient hostname goes stale the same way.
  print "nixdev-apply: restarting to pick up the new login shell..."
  limactl restart --tty=false nixdev
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
