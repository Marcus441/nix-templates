# dotnet (Nix Flake Template)

A minimal Nix flake template for .NET projects. Provides a reproducible dev shell with the right SDK 
— scaffold the project itself with `dotnet new` after entering the shell.

## Usage

### 1. Enter the dev shell

```bash
nix develop
```

### 2. Scaffold your project

```bash
dotnet new console -n MyApp      # or: webapi, classlib, xunit, etc.
```

### 3. Update `flake.nix`

Edit the config block at the top of `flake.nix` to match your scaffolded project:

```nix
projectName     = "MyApp";
projectFile     = "./MyApp/MyApp.csproj";
testProjectFile = "./MyApp.Test/MyApp.Test.csproj";
version         = "0.0.1";
dotnet-version  = "dotnet_10";  # dotnet_6 | dotnet_7 | dotnet_8 | dotnet_9 | dotnet_10
```

### 4. Generate NuGet deps

Once your project has NuGet dependencies (i.e. after `dotnet restore`), generate the Nix lockfile:

```bash
nix build .#default.passthru.fetch-deps && ./result
```

This produces `nix/deps.nix`. Commit it alongside your project.

### 5. Build

```bash
nix build
```

---

## Adding F# tooling

If you're using F#, the flake can be extended to package tools like `fantomas` and `fsharp-analyzers`
from NuGet using the `mkDotnetTool` helper. See the comments in `flake.nix`.

---

## Notes

- `projectFile` and `testProjectFile` can be set to `null` to let `buildDotnetModule` auto-discover `.csproj`/`.fsproj` files.
- Tests run automatically during `nix build` (`doCheck = true`). Set to `false` to skip.
- Uncomment `DOTNET_CLI_TELEMETRY_OPTOUT = "1"` in the `devShell` block to disable telemetry.
- Run `nix fmt` to format `flake.nix` with `alejandra`.
