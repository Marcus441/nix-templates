{
  description = ".NET project template with a reproducible SDK dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        inherit (nixpkgs) lib;

        # ── Project configuration ─────────────────────────────────────────────
        # TODO: Edit these to match the project you scaffold with `dotnet new`.
        projectName = "HelloWorld";
        projectFile = "./${projectName}/${projectName}.fsproj";
        testProjectFile = "./${projectName}.Test/${projectName}.Test.fsproj";
        version = "0.0.1";

        # ── .NET version ──────────────────────────────────────────────────────
        # Options: dotnet_8, dotnet_9, dotnet_10
        dotnet-version = "dotnet_10";
        dotnet-sdk = pkgs.dotnetCorePackages.${dotnet-version}.sdk;
        dotnet-runtime = pkgs.dotnetCorePackages.${dotnet-version}.runtime;

        # ── NuGet dependency lock ─────────────────────────────────────────────
        # This template ships without one, because the deps of a project that
        # does not exist yet cannot be locked. `null` is not a placeholder: it
        # is the value that makes `passthru.fetch-deps` exist, which is what
        # generates the file. Until then there is nothing to build, so
        # `packages` is empty and the dev shell is the whole template.
        depsFile =
          if builtins.pathExists ./nix/deps.json
          then ./nix/deps.json
          else if builtins.pathExists ./nix/deps.nix
          then ./nix/deps.nix
          else null;

        # ── Extra dev tools ───────────────────────────────────────────────────
        devTools = with pkgs; [
          git
          alejandra # Nix formatter
          fantomas # F# formatter
          # nodePackages.prettier
          # just
        ];
      in {
        # Present only once `nix/deps.json` exists — see depsFile above.
        packages = lib.optionalAttrs (depsFile != null) {
          default = pkgs.buildDotnetModule {
            pname = projectName;
            inherit version projectFile testProjectFile dotnet-sdk dotnet-runtime;
            src = ./.;
            nugetDeps = depsFile;
            doCheck = true;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [dotnet-sdk] ++ devTools;

          # Keeps the SDK from writing telemetry and from creating a
          # ~/.dotnet/ first-run sentinel inside a build sandbox.
          DOTNET_CLI_TELEMETRY_OPTOUT = "1";
          DOTNET_NOLOGO = "1";
          DOTNET_ROOT = "${dotnet-sdk}";
        };

        formatter = pkgs.alejandra;
      }
    );
}
