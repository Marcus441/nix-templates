{
  description = "project templates";

  # These inputs belong to this repository's own tooling — the checks, the
  # formatter and the test harness. Templates share none of them: each template
  # is a standalone flake with its own inputs (CLAUDE.md 1).
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
      imports = [./meta];
    };
}
