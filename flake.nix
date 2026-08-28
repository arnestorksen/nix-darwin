{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux"; # or aarch64-linux
  in
  {
    nixosConfigurations.gamix = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/gamix/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.users.arne = import ./home/linux.nix;
        }
      ];
    };
  };
}
