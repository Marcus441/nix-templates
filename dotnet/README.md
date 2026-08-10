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

Until this file exists there is **no `packages` output** — only the dev shell.
That is deliberate: the dependencies of a project you have not scaffolded yet
cannot be locked, and `nugetDeps = null` is what makes the generator below
exist in the first place.

Once your project has NuGet dependencies (i.e. after `dotnet restore`):

```bash
nix build .#default.passthru.fetch-deps && ./result "$PWD/nix/deps.json"
```

Pass the path explicitly — inside a flake the source is a store path, so the
script cannot infer where you want the file written. Commit `nix/deps.json`
alongside your project.

### 5. Build

`packages.default` appears as soon as `nix/deps.json` is present:

```bash
nix build
```

---

## F# tooling

`fantomas` (the F# formatter) comes from nixpkgs and is already in the dev
shell. For a tool that is not packaged in nixpkgs, use
`pkgs.buildDotnetGlobalTool` — you supply `nugetHash`, which you get from the
first failed build.

Do **not** read `.config/dotnet-tools.json` from Nix. Keep it as a genuine
`dotnet tool restore` artifact used by the CLI: a template that reads a file it
does not ship cannot be evaluated by whoever just initialised it.

---

## Notes

- `projectFile` and `testProjectFile` can be set to `null` to let `buildDotnetModule` auto-discover `.csproj`/`.fsproj` files.
- Tests run automatically during `nix build` (`doCheck = true`). Set to `false` to skip.
- Uncomment `DOTNET_CLI_TELEMETRY_OPTOUT = "1"` in the `devShell` block to disable telemetry.
- Run `nix fmt` to format `flake.nix` with `alejandra`.
