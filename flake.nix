{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    sidra.url = "github:wimpysworld/sidra";
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, sidra, ... }:
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
          home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
          home-manager.extraSpecialArgs = {
            sidraPkg = sidra.packages.${system}.default;
          };
          home-manager.users.arne = import ./home/linux.nix;
        }
      ];
    };
  };
}
