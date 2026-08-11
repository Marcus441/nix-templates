# dotnet

Dev environment with dotnet sdk and runtime. The dev shell gives you the SDK;
you scaffold the project itself with `dotnet new` after entering it.

```bash
nix flake init -t github:Marcus441/nix-templates#dotnet
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
```

## What you get

The .NET 10 SDK, `git`, `alejandra` (Nix formatter) and `fantomas` (F#
formatter). `config.allowUnfree = true` is set inside the flake, so nothing
extra is needed on the command line.

There is deliberately **no `packages` output** until you generate a NuGet lock —
see Building.

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
nix build .#default.passthru.fetch-deps && ./result "$PWD/nix/deps.json"
```

Pass the path explicitly. Inside a flake the source is a store path, so the
script cannot infer where you want the file written. Commit `nix/deps.json`
alongside your project.

### 4. Build

`packages.default` appears as soon as `nix/deps.json` is present:

```bash
nix build
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

- **`nugetDeps = null` is not a placeholder.** It is the value that makes
  `passthru.fetch-deps` exist, which is what generates the lock in the first
  place. The deps of a project you have not scaffolded yet cannot be locked, so
  until `nix/deps.json` appears the `packages` output is empty and the dev shell
  is the whole template. The flake guards on `builtins.pathExists`, so it stays
  evaluatable as shipped.
- `projectFile` and `testProjectFile` can be set to `null` to let
  `buildDotnetModule` auto-discover the `.csproj`/`.fsproj` files.
- `DOTNET_CLI_TELEMETRY_OPTOUT` and `DOTNET_NOLOGO` are set in the dev shell.
  They keep the SDK from phoning home and from writing a `~/.dotnet/` first-run
  sentinel inside a build sandbox.
- `nix fmt` formats `flake.nix` with alejandra.
