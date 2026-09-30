# The nixdev guest (mixos, ~/code/mixos) as this machine wants it. A separate
# subflake on purpose: the guest evaluates this, and must never need the
# top-level flake's inputs -- dokken-aws-helper is git+ssh behind the
# 1Password agent, which the guest has no way to reach.
#
# Applied by nixdev-apply (darwin/nixdev.zsh), which finds it via MIXOS_FLAKE.
{
  description = "nixdev guest for ars, built on mixos";

  inputs = {
    # No remote yet. nixdev-apply overrides this with its copy in the guest.
    mixos.url = "git+file:///Users/ars/code/mixos";
    nixpkgs.follows = "mixos/nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, mixos, home-manager, ... }:
    {
      nixosConfigurations.nixdev = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          mixos.nixosModules.default
          home-manager.nixosModules.home-manager
          ./guest.nix
        ];
      };
    };
}
