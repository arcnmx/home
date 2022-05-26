{
  description = "nix/home";
  inputs = {
    std.url = "github:flakelib/std";
    flakelib = {
      url = "github:flakelib/fl";
      inputs.std.follows = "std";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    linuxPackages = {
      url = "github:flakelib/pkgs/linux";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakelib.follows = "flakelib";
      };
    };
    base16 = {
      url = "github:flakelib/pkgs/base16";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakelib.follows = "flakelib";
        std.follows = "std";
      };
    };
    wireplumber-scripts-arc = {
      url = "github:arcnmx/wireplumber-scripts";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakelib.follows = "flakelib";
      };
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    meta = {
      url = "github:flakelib/pkgs/meta";
      inputs = {
        flakelib.follows = "flakelib";
        nixpkgs.follows = "nixpkgs";
        std.follows = "std";
      };
    };
    arc = {
      url = "github:arcnmx/nixexprs/2205";
      flake = false;
    };
    rust = {
      url = "github:arcnmx/nixexprs-rust";
      flake = false;
    };
    tf = {
      url = "github:arcnmx/tf-nix";
      flake = false;
    };
    /*ci = {
      url = "github:flakelib/ci";
      inputs = {
        flakelib.follows = "flakelib";
        nixpkgs.follows = "nixpkgs";
      };
    };*/
  };
  outputs = { flakelib, ... }@inputs: flakelib {
    inherit inputs;
    systems = let
      pinecube = inputs.std.lib.System (import ./hw/pinecube/system.nix {
        inherit (inputs.nixpkgs.lib) systems;
      });
    in [
      "x86_64-linux"
      "aarch64-linux"
      pinecube
      {
        name = "pinecube-cross";
        localSystem = "x86_64-linux";
        crossSystem = pinecube;
      }
    ];
    devShells = ./ci/shells.nix;
    nixosModules = ./modules;
    nixosConfigurations = { outputs }: outputs.config.nodes;
    outputs.config.value = ./cfg;
  };
}
