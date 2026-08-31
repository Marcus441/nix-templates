# dotnet

devenv environment for .NET, with F# tooling. The environment gives you the
SDK; you scaffold the project itself with `dotnet new` after entering it.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **the .NET 10 SDK** (`dotnetCorePackages.sdk_10_0`)
- **`fantomas`**, the F# formatter, from nixpkgs
- **telemetry and first-run noise already off** — `DOTNET_CLI_TELEMETRY_OPTOUT`
  and `DOTNET_NOLOGO` are set in `env`

What you do *not* get is a project: `dotnet new` writes a better one than this
template could keep current.

## Building

### 1. Scaffold your project

```bash
dotnet new console -n MyApp      # or: webapi, classlib, xunit, etc.
```

### 2. Build and run

```bash
dotnet build MyApp
dotnet run --project MyApp
```

Plain `dotnet` commands — no Nix build wraps them, so there is no NuGet lock
file to generate and nothing to regenerate when a dependency changes.
`dotnet restore` talks to nuget.org directly.

### 3. Test

```bash
dotnet new xunit -n MyApp.Tests
dotnet test MyApp.Tests
```

## F# tooling

`fantomas` comes from nixpkgs and is already on `PATH`. For a tool nixpkgs does
not package, `.config/dotnet-tools.json` and `dotnet tool restore` work as they
would anywhere — nothing here evaluates that file.

## Notes

- **`languages.dotnet.lsp.enable` is `false` deliberately.** The default is
  computed as `availableOn <host> csharp-ls`, and `csharp-ls` declares
  `badPlatforms = ["aarch64-darwin"]` — so on an Apple Silicon Mac the default
  resolves to *false* and the server is silently absent. Rather than ship a
  language server that exists on some platforms and not others, this template
  ships none. Opt in with `lsp.enable = true; lsp.package = pkgs.roslyn-ls;` —
  the `dotnet-react-postgres` template in this collection is the worked
  example.
- **The SDK is pinned to `sdk_10_0`** rather than tracking devenv's default,
  which is .NET 8. A pinned major eventually leaves nixpkgs, so treat it as
  something to bump rather than something to forget;
  `languages.dotnet.package` is the knob.
- **Everything here evaluates free.** If you add an unfree package, put
  `allowUnfree: true` at the top of `devenv.yaml`.
- **`DOTNET_CLI_TELEMETRY_OPTOUT` and `DOTNET_NOLOGO`** keep the SDK from
  phoning home and from printing the first-run banner (and writing its
  `~/.dotnet` sentinel) the first time it runs.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own modules float, and
  the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `fantomas` covers the F# side,
  `dotnet format` the C# side, and devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).
