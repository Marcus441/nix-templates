{
  description = ".NET Project Template";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
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

        # ── Project configuration ─────────────────────────────────────────────
        # TODO: Edit these to match your project
        projectName = "HelloWorld";
        projectFile = "./${projectName}/${projectName}.fsproj";
        testProjectFile = "./${projectName}.Test/${projectName}.Test.fsproj";
        version = "0.0.1";

        # ── .NET version ──────────────────────────────────────────────────────
        # Options: dotnet_6, dotnet_7, dotnet_8, dotnet_9, dotnet_10
        dotnet-version = "dotnet_10";
        dotnet-sdk = pkgs.dotnetCorePackages.${dotnet-version}.sdk;
        dotnet-runtime = pkgs.dotnetCorePackages.${dotnet-version}.runtime;

        # ── Dotnet tool runtime version ───────────────────────────────────────
        # The NuGet tools below were built for net6.0; change if your tools
        # target a different TFM (e.g. "net8.0")
        toolTargetFramework = "net6.0";

        # ── Helper: build a dotnet CLI tool from NuGet ────────────────────────
        # dllOverride: pass null to use toolName as the DLL name, or a string
        #              to override (e.g. "FSharp.Analyzers.Cli")
        mkDotnetTool = dllOverride: toolName: let
          toolVersion =
            (builtins.fromJSON (builtins.readFile ./.config/dotnet-tools.json))
            .tools."${toolName}".version;
          inherit
            ((builtins.head (
              builtins.filter (e: e.pname == toolName)
              ((import ./nix/deps.nix) {fetchNuGet = x: x;})
            )))
            sha256
            ;
          dllName =
            if dllOverride == null
            then toolName
            else dllOverride;
        in
          pkgs.stdenvNoCC.mkDerivation {
            name = toolName;
            version = toolVersion;
            nativeBuildInputs = [pkgs.makeWrapper];
            src = pkgs.fetchNuGet {
              pname = toolName;
              version = toolVersion;
              inherit sha256;
              installPhase = ''
                mkdir -p $out/bin
                cp -r tools/${toolTargetFramework}/any/* $out/bin
              '';
            };
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/lib"
              cp -r ./bin/* "$out/lib"
              makeWrapper "${dotnet-runtime}/bin/dotnet" "$out/bin/${toolName}" \
                --add-flags "$out/lib/${dllName}.dll"
              runHook postInstall
            '';
          };

        # ── Extra dev tools ───────────────────────────────────────────────────
        # Add/remove packages for your shell environment
        devTools = with pkgs; [
          git
          alejandra # Nix formatter
          # nodePackages.prettier
          # just
        ];
      in {
        # ── Packages ──────────────────────────────────────────────────────────
        packages = {
          # F# tools — remove the block entirely if you're using C#
          fantomas = mkDotnetTool null "fantomas";
          fsharp-analyzers = mkDotnetTool "FSharp.Analyzers.Cli" "fsharp-analyzers";

          default = pkgs.buildDotnetModule {
            pname = projectName;
            inherit version projectFile testProjectFile dotnet-sdk dotnet-runtime;
            src = ./.;
            nugetDeps = ./nix/deps.nix; # regenerate: nix build .#default.passthru.fetch-deps && ./result
            doCheck = true;
          };
        };

        # ── Dev shell ─────────────────────────────────────────────────────────
        devShells.default = pkgs.mkShell {
          buildInputs = [dotnet-sdk] ++ devTools;

          # Opt-in: uncomment to disable dotnet telemetry in the shell
          # DOTNET_CLI_TELEMETRY_OPTOUT = "1";

          # Opt-in: pin DOTNET_ROOT so tools can locate the runtime
          # DOTNET_ROOT = "${dotnet-sdk}";
        };

        # ── Formatter (run with `nix fmt`) ────────────────────────────────────
        formatter = pkgs.alejandra;
      }
    );
}
