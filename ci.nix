{ config, channels, pkgs, lib, ... }: with pkgs; with lib; let
  inherit (import ./. { inherit pkgs; }) checks;
in {
  name = "ddc-macos-rs";
  ci.gh-actions.enable = true;
  cache.cachix = {
    ci.signingKey = "";
    arc.enable = true;
  };
  channels = {
    nixpkgs = "22.11";
  };
  tasks = {
  };
  jobs = {
    macos = {
      tasks = {
        build.inputs = singleton checks.test;
        fmt.inputs = singleton checks.rustfmt;
      };
      system = "x86_64-darwin";
    };
  };
}
