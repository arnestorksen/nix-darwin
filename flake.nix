{
  description = "My nix-darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
    let
      # Helper function to create darwin configuration
      mkDarwinConfig = hostname: username: nix-darwin.lib.darwinSystem {
        specialArgs = { inherit hostname username; };
        modules = [
          ./configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = { inherit hostname username; };
          }
        ];
      };
    in
    {
      # Configuration for work Mac
      darwinConfigurations."BGOMAC-ars" = mkDarwinConfig "BGOMAC-ars" "ars";

      # Configuration for home Mac
      darwinConfigurations."MacBookPro.storksen.home" = mkDarwinConfig "MacBookPro.storksen.home" "arne";
      # Add configurations for other machines here, for example:
      # darwinConfigurations."MacBook-Pro" = mkDarwinConfig "MacBook-Pro" "ars";
    };
}
