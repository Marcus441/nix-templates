# dotnet

Dev environment for .NET, with F# tooling. The dev shell gives you the SDK; you
scaffold the project itself with `dotnet new` after entering it.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

The .NET 10 SDK and `fantomas` (F# formatter). `config.allowUnfree = true` is
set inside the flake, so nothing extra is needed on the command line.

Two package outputs, and which of them exists depends on your project:

| Output | When it exists |
| --- | --- |
| `packages.fetch-deps` | always — it is what generates the NuGet lock |
| `packages.default` | once `nix/deps.json` is present |

## Building

### 1. Scaffold your project

```bash
dotnet new console -n MyApp      # or: webapi, classlib, xunit, etc.
```

### 2. Update `flake.nix`

Edit the values at the top of the `let` block to match what you scaffolded:

```nix
projectName = "MyApp";
projectFile = "./MyApp/MyApp.csproj";
testProjectFile = "./MyApp.Test/MyApp.Test.csproj";
version = "0.0.1";
dotnetVersion = "dotnet_10";  # dotnet_8 | dotnet_9 | dotnet_10
```

### 3. Generate NuGet deps

Once the project has NuGet dependencies — that is, after `dotnet restore`:

```bash
git add -A                                       # the flake must see the project
nix build '.#fetch-deps' && ./result "$PWD/nix/deps.json"
```

Pass the path explicitly. Inside a flake the source is a store path, so the
script cannot infer where you want the file written. Commit `nix/deps.json`
alongside your project, and re-run this whenever a NuGet dependency changes.

### 4. Build

`packages.default` appears as soon as `nix/deps.json` is present:

```bash
nix build
nix run                 # runs the built binary
```

## Testing

Tests run automatically during `nix build` (`doCheck = true`). Set it to `false`
to skip them. Outside Nix, `dotnet test` as usual.

## F# tooling

`fantomas` comes from nixpkgs and is already in the dev shell. For a tool that
is not packaged in nixpkgs, use `pkgs.buildDotnetGlobalTool` — you supply
`nugetHash`, which you get from the first failed build.

Do **not** read `.config/dotnet-tools.json` from Nix. Keep it as a genuine
`dotnet tool restore` artifact used by the CLI: a template that reads a file it
does not ship cannot be evaluated by whoever just initialised it.

## Notes

- **`nugetDeps` points at `./nix/deps.json` before that file exists, and that is
  deliberate.** `passthru.fetch-deps` — the script that writes the lock — only
  exists when `nugetDeps` is a *path*; pass `null` and `buildDotnetModule` never
  applies `addNuGetDeps` at all, so there is nothing to generate the lock with.
  A path to a missing file is exactly what makes the bootstrap reachable.
- **`packages.default` is guarded on `builtins.pathExists`, `fetch-deps` is
  not.** Reading a missing `deps.json` would make the template un-evaluatable
  the moment someone initialises it, so the package that needs the file waits
  for it. The generator does not read it and therefore does not have to wait —
  which is the whole point, since it is what creates the file.
- `projectFile` and `testProjectFile` can be set to `null` to let
  `buildDotnetModule` auto-discover the `.csproj`/`.fsproj` files.
- `DOTNET_CLI_TELEMETRY_OPTOUT` and `DOTNET_NOLOGO` are set in the dev shell.
  They keep the SDK from phoning home and from writing a `~/.dotnet/` first-run
  sentinel inside a build sandbox.
- `nix fmt` formats `flake.nix` with alejandra.
