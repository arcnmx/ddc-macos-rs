{
  inputs = {
    flakelib.url = "github:flakelib/fl";
    nixpkgs = { };
    rust = {
      url = "github:arcnmx/nixexprs-rust";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arc = {
      url = "github:arcnmx/nixexprs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, flakelib, nixpkgs, rust, ... }@inputs: let
    nixlib = nixpkgs.lib;
    defaultTarget = "x86_64-apple-darwin";
  in flakelib {
    inherit inputs;
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    devShells = {
      plain = {
        mkShell, writeShellScriptBin, hostPlatform
      , udev
      , pkg-config, python3
      , libiconv
      , CoreGraphics ? darwin.apple_sdk.frameworks.CoreGraphics, darwin
      , enableRust ? true, cargo
      , rustTools ? [ ]
      }: mkShell {
        inherit rustTools;
        buildInputs =
          nixlib.optionals hostPlatform.isDarwin [ libiconv CoreGraphics ];
        nativeBuildInputs = [ pkg-config python3 ]
          ++ nixlib.optional enableRust cargo
          ++ [
            (writeShellScriptBin "generate" ''nix run .#generate "$@"'')
          ];
        ${if !hostPlatform.isDarwin then "CARGO_BUILD_TARGET" else null} = defaultTarget;
        RUST_LOG = "ddc=debug";
      };
      stable = { rust'stable, outputs'devShells'plain }: outputs'devShells'plain.override {
        inherit (rust'stable) mkShell;
        enableRust = false;
      };
      dev = { arc'rustPlatforms'nightly, rust'distChannel, outputs'devShells'plain, rust-darwin-overlay }: let
        channel = rust'distChannel {
          inherit (arc'rustPlatforms'nightly) channel date manifestPath;
          channelOverlays = [ rust-darwin-overlay ];
        };
      in outputs'devShells'plain.override {
        inherit (channel) mkShell;
        enableRust = false;
        rustTools = [ "rust-analyzer" ];
      };
      default = { outputs'devShells }: outputs'devShells.plain;
    };
    legacyPackages = { callPackageSet }: callPackageSet {
      source = { rust'builders }: rust'builders.wrapSource self.lib.crate.src;

      rust-darwin-overlay = { }: let
        darwinSystems = nixlib.mapAttrsToList (_: nixlib.systems.elaborate) (
          nixlib.filterAttrs (_: nixlib.hasSuffix "-darwin") self.flakes.systems
        );
      in cself: csuper: {
        sysroot-std = csuper.sysroot-std ++ map (platform:
          cself.manifest.targets.${cself.context.rlib.rustTargetFor platform}.rust-std
        ) darwinSystems;
      };

      generate = { rust'builders, outputHashes }: rust'builders.generateFiles {
        paths = {
          "lock.nix" = outputHashes;
        };
      };
      outputHashes = { rust'builders }: rust'builders.cargoOutputHashes {
        inherit (self.lib) crate;
      };
    } { };
    checks = {
      test = { outputs'devShells'plain, rustPlatform, source }: rustPlatform.buildRustPackage {
        pname = self.lib.crate.package.name;
        inherit (self.lib.crate) version cargoLock;
        inherit (outputs'devShells'plain.override { enableRust = false; }) buildInputs nativeBuildInputs;
        src = source;
        cargoBuildFlags = [ "--all" ];
        cargoTestFlags = [ "--all" ];
        buildType = "debug";
        meta.name = "cargo test";
      };
    };
    lib = with nixlib; {
      crate = rust.lib.importCargo {
        path = ./Cargo.toml;
        inherit (import ./lock.nix) outputHashes;
      };
      inherit (self.lib.crate) version;
      releaseTag = "v${self.lib.version}";
    };
    config = rec {
      name = "ddc-macos-rs";
    };
  };
}
