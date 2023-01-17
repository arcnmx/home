{
  description = "nix/home";
  inputs = {
    std.url = "github:flakelib/std";
    flakelib = {
      url = "github:flakelib/fl";
      inputs.std.follows = "std";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-big.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arc = {
      url = "github:arcnmx/nixexprs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust = {
      url = "github:arcnmx/nixexprs-rust";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tf = {
      url = "github:arcnmx/tf-nix";
      flake = false;
    };
    qemucomm = {
      url = "github:arcnmx/qemucomm";
      flake = false;
    };
    wireplumber-scripts = {
      url = "github:arcnmx/wireplumber-scripts";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust.follows = "rust";
        flakelib.follows = "flakelib";
      };
    };
    systemd2mqtt = {
      url = "github:arcnmx/systemd2mqtt";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust.follows = "rust";
        flakelib.follows = "flakelib";
      };
    };
  };
  outputs = { self, ... }@inputs: {
    nixosConfigurations = self.config.network.nodes;
    config = import ./config {
      inherit inputs;
    };
  };
}
