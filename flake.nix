{
  description = "My nix-darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-work-env.url = "git+ssh://git@github.com/tv2norge/nix-dokken-dev";
    nix-work-env.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-work-env }:
    {
      # Work Mac (ARM)
      darwinConfigurations."Mac-TM7WHWRD7G" = nix-darwin.lib.darwinSystem {
        specialArgs = { hostname = "Mac-TM7WHWRD7G"; username = "ars"; platform = "aarch64-darwin"; };
        modules = [
          ./configuration.nix
          nix-work-env.darwinModules.work
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { hostname = "Mac-TM7WHWRD7G"; username = "ars"; };
            home-manager.users.ars = {
              imports = [ ./home.nix nix-work-env.homeManagerModules.work ];
              tv2.workEnv = {
                enable = true;
                workEmail = "arne.storksen@tv2.no";
                gitUserName = "Arne Mellesmo Størksen";
                sshSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqRo+OElcjXCy4JqZyE2gSDd1wUiDx+u5xs1XYLDAxt";
                enable1PasswordSigning = true;
                dokkenAwsHelperPackage = nix-work-env.packages.aarch64-darwin.dokken-aws-helper;
                personalEmail = "arne.storksen@gmail.com";
                personalSigningKey = "D923C0D7FA86BA69";
                personalRepoDirs = [ "~/code/private/" "~/.config/nix-darwin/" ];
              };
            };
          }
        ];
      };

      # Home Mac (Intel)
      darwinConfigurations."arne-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { hostname = "arne-mac"; username = "arne"; platform = "x86_64-darwin"; };
        modules = [
          ./configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { hostname = "arne-mac"; username = "arne"; };
            home-manager.users.arne = {
              imports = [ ./home.nix ];
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
