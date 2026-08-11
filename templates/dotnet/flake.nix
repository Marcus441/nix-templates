{
  description = "Dev environment for .NET, with F# tooling";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system:
          f (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          })
      );

    projectName = "HelloWorld";
    projectFile = "./${projectName}/${projectName}.fsproj";
    testProjectFile = "./${projectName}.Test/${projectName}.Test.fsproj";
    version = "0.0.1";
    dotnetVersion = "dotnet_10";
    depsFile = ./nix/deps.json;
  in {
    packages = forAllSystems (pkgs: let
      module = pkgs.buildDotnetModule {
        pname = projectName;
        inherit version projectFile testProjectFile;
        dotnet-sdk = pkgs.dotnetCorePackages.${dotnetVersion}.sdk;
        dotnet-runtime = pkgs.dotnetCorePackages.${dotnetVersion}.runtime;
        src = ./.;
        nugetDeps = depsFile;
        doCheck = true;
        meta.mainProgram = projectName;
      };
    in
      {inherit (module.passthru) fetch-deps;}
      // nixpkgs.lib.optionalAttrs (builtins.pathExists depsFile) {
        default = module;
      });

    devShells = forAllSystems (pkgs: let
      dotnet-sdk = pkgs.dotnetCorePackages.${dotnetVersion}.sdk;
    in {
      default = pkgs.mkShellNoCC {
        name = "dotnet";
        packages = [
          dotnet-sdk
          pkgs.fantomas
        ];
        env = {
          DOTNET_CLI_TELEMETRY_OPTOUT = "1";
          DOTNET_NOLOGO = "1";
          DOTNET_ROOT = "${dotnet-sdk}";
        };
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
