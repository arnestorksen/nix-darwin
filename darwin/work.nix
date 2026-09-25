{ config, lib, pkgs, inputs, ... }:

# Work Mac (Mac-TM7WHWRD7G) only -- imported from flake.nix alongside
# ../home/darwin.nix, which holds everything shared with the home Mac. Migrated here
# from the separate `nix-dokken-dev` flake (~/code/nix-work-env); it had a
# `tv2.workEnv.*` option surface for reuse by colleagues, which nobody ever
# took up, so the values are inlined directly now.

let
  system = pkgs.stdenv.hostPlatform.system;

  dash0 = inputs.dash0-nur.packages.${system}.dash0;
  dokken-aws-helper = inputs.dokken-aws-helper.packages.${system}.default;
in
{
  # Work-only tooling. Anything also wanted on the home Mac (python3, uv,
  # ripgrep, jq, docker, gh, ...) lives in ../home/darwin.nix instead, so this
  # list is deliberately just the delta.
  home.packages = with pkgs; [
    # Data tools
    yq-go

    # Secret management
    sops

    # MCP servers runtime
    nodejs

    # Cloud CLIs
    awscli2
    azure-cli
    amazon-ecr-credential-helper
    (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])

    # Kubernetes tools
    kubectl
    kustomize
    kubelogin
    kubectx # includes kubens
    kubernetes-helm
    kind
    dapr-cli
    argocd
    cilium-cli
    hubble

    _1password-cli

    # Observability -- pre-built binary from dash0hq/nur rather than the
    # source build in the dash0-cli flake's own buildGoModule output.
    dash0

    # Internal TV2 tooling (private flake input)
    dokken-aws-helper

    # Linux VM for running Linux Nix store binaries (see nix-linux below)
    lima
  ];

  # Work identity + SSH commit signing via 1Password. ../home/darwin.nix leaves
  # programs.git.settings.user unset, so this is the default identity on this
  # machine; the includes below carve out personal repos.
  programs.git.settings = {
    user.email = "arne.storksen@tv2.no";
    user.name = "Arne Mellesmo Størksen";
    user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqRo+OElcjXCy4JqZyE2gSDd1wUiDx+u5xs1XYLDAxt";
    commit.gpgSign = true;
    gpg.format = "ssh";
    "gpg \"ssh\"" = {
      program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
    };
  };

  # Fall back to personal identity (and OpenPGP signing) in these directories,
  # so work repos sign as TV2 and personal ones don't. Merges with the
  # idpGitHooks include in git-issue-workflow.nix -- programs.git.includes is
  # a list option.
  programs.git.includes = map
    (dir: {
      condition = "gitdir:${dir}";
      contents = {
        user.email = "arne.storksen@gmail.com";
        user.signingKey = "D923C0D7FA86BA69";
        gpg.format = "openpgp";
      };
    })
    [ "~/code/private/" "~/.config/nix-darwin/" ];

  home.sessionVariables = {
    GOPROXY = "https://proxy.golang.tv2.no";
    GONOSUMDB = "bitbucket.org/tv2norge/*,golang.tv2.no/*";

    # 1Password's SSH Agent is only used for git commit *signing* via
    # `gpg.ssh.program` above, which talks to it directly and doesn't need
    # SSH_AUTH_SOCK. Actual SSH auth (git push/fetch over ssh, `ssh -T`,
    # etc.) still goes through whatever agent SSH_AUTH_SOCK points at, and
    # 1Password does not override that globally -- without this, those
    # commands silently fall back to the default macOS agent, which has no
    # identities loaded.
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
  };

  # Lima VM that mounts /nix/store read-only, so Linux Nix store binaries can
  # be run directly without Docker. Apple Virtualization.framework + Rosetta,
  # so both aarch64-linux and x86_64-linux binaries work.
  home.file.".lima/nix-linux/lima.yaml".text = ''
    vmType: vz
    vmOpts:
      vz:
        rosetta:
          enabled: true
          binfmt: true
    images:
      - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
        arch: aarch64
    cpus: 4
    memory: 4GiB
    disk: 20GiB
    mounts:
      - location: /nix/store
        mountPoint: /nix/store
        writable: false
    mountType: virtiofs
  '';

  programs.zsh.initContent = ''
    # Build as user (so SSH agent works for private flake inputs), then activate as root
    nix-rebuild() {
      local flake=''${1:-~/.config/nix-darwin}
      local hostname=$(hostname -s)
      local system
      system=$(nix build --no-link --print-out-paths "$flake#darwinConfigurations.$hostname.system") || return 1
      sudo "$system/sw/bin/darwin-rebuild" activate
    }

    # Start the nix-linux Lima VM (if not running) and open a shell or run a command
    nix-linux() {
      limactl start --tty=false nix-linux 2>/dev/null || true
      limactl shell nix-linux "$@"
    }
  '';

  # Sync GitHub PAT from 1Password to macOS Keychain at login.
  # Trigger manually: launchctl kickstart -k gui/$UID/sync-secrets
  launchd.agents.sync-secrets = {
    enable = true;
    config = {
      Label = "sync-secrets";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          PAT=$(${lib.getExe pkgs._1password-cli} read "op://Private/Github/PAT" 2>/dev/null)
          [ -n "$PAT" ] && /usr/bin/security add-generic-password -U -a "$USER" -s "github-pat" -w "$PAT"
        ''
      ];
      RunAtLoad = true;
    };
  };
}
