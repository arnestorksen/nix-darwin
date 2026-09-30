# The nixdev guest (mixos, ~/code/mixos) as this machine wants it. A separate
# subflake on purpose: the guest evaluates this, and must never need the
# top-level flake's inputs -- dokken-aws-helper is git+ssh behind the
# 1Password agent, which the guest has no way to reach.
#
# Applied by nixdev-apply (~/code/mixos/shell), which finds it via MIXOS_FLAKE,
# set in darwin/work.nix.
{
  description = "nixdev guest for ars, built on mixos";

  inputs = {
    # mixos is always consumed from the local clone. This URL only serves
    # locking on the host; in the guest nixdev-apply overrides it with its copy.
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
