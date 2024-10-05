{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    esp-dev = {
      url = "github:mirrexagon/nixpkgs-esp-dev";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, esp-dev, crane, ... }:
  {
    overlays.default = import ./nix/overlay.nix;
  }
  // flake-utils.lib.eachDefaultSystem
    (system:
    let
      overlays = [
        fenix.overlays.default
        esp-dev.overlays.default
        self.overlays.default
      ];

      pkgs = import nixpkgs { inherit system overlays; };

      rustToolchain = with fenix.packages.${system}; combine [
        pkgs.rust-esp
        pkgs.rust-src-esp
      ];

      craneLib = crane.mkLib pkgs;
      craneToolchain = craneLib.overrideToolchain rustToolchain;
      src = craneLib.cleanCargoSource ./.;
      commonArgs = {
        inherit src;
        strictDeps = true;

        buildInputs = with pkgs; [
          esp-idf-esp32
        ];
      };

      cargoArtifacts = craneToolchain.buildDepsOnly commonArgs;

      crate = craneToolchain.buildPackage (commonArgs // {
        inherit cargoArtifacts;
      });
    in
    {
      devShells.default = with pkgs; mkShell {
        buildInputs = [
          openssl
          pkg-config
          esp-idf-esp32

          rustToolchain

          cargo-generate
          cargo-espflash
        ];
      };

      packages.default = crate;
    });
}
