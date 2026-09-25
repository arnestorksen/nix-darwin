{
  description = "My nix-darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # Work Mac only (see work.nix). dokken-aws-helper is a private TV2 repo
    # fetched over git+ssh -- this is why the work Mac needs the
    # build-as-user/activate-as-root split (`nix-rebuild`), see README.
    dokken-aws-helper.url = "git+ssh://git@github.com/tv2norge/dokken-aws-helper";
    dokken-aws-helper.inputs.nixpkgs.follows = "nixpkgs";
    # Pre-built dash0 CLI binaries; the dash0-cli flake itself only exposes a
    # buildGoModule source build, which nothing caches.
    dash0-nur.url = "github:dash0hq/nur";
    dash0-nur.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, determinate, ... }:
    {
      # Work Mac (ARM)
      darwinConfigurations."Mac-TM7WHWRD7G" = nix-darwin.lib.darwinSystem {
        specialArgs = { hostname = "Mac-TM7WHWRD7G"; username = "ars"; platform = "aarch64-darwin"; };
        modules = [
          ./hosts/work-mac/configuration.nix
          determinate.darwinModules.default
          ({ ... }: { determinateNix.enable = true; })
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs; hostname = "Mac-TM7WHWRD7G"; username = "ars"; };
            home-manager.users.ars = {
              imports = [ ../home/darwin.nix ./git-issue-workflow.nix ./work.nix ];
            };
          }
        ];
      };

      # Home Mac (Intel)
      darwinConfigurations."arne-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { hostname = "arne-mac"; username = "arne"; platform = "x86_64-darwin"; };
        modules = [
          ./hosts/arne-mac/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs; hostname = "arne-mac"; username = "arne"; };
            home-manager.users.arne = {
              imports = [ ../home/darwin.nix ./git-issue-workflow.nix ];
              programs.git.settings = {
                user.name = "Arne Mellesmo Størksen";
                user.email = "arne.storksen@gmail.com";
                user.signingKey = "D923C0D7FA86BA69";
                commit.gpgSign = true;
                gpg.format = "openpgp";
              };
            };
          }
        ];
      };
    };
}
