{
  description = "nix/home";
  inputs = {
    std.url = "github:flakelib/std";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-big.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arc = {
      url = "github:arcnmx/nixexprs";
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
    qemucomm = {
      url = "github:arcnmx/qemucomm";
      flake = false;
    };
  };
  outputs = { self, ... }@inputs: {
    nixosConfigurations = self.config.network.nodes;
    config = import ./config {
      inherit inputs;
    };
  };
}
