# The registry. Adding an entry here is what publishes a template.
# Field semantics and how to choose a tier: .claude/rules/registry.md.
{
  templates = {
    android-kotlin = {
      description = "Dev environment for Android with Kotlin, Jetpack Compose and Google's Android CLI";
      tier = "shell";
      smoke = ["android --version" "gradle --version" "kotlinc -version" "ktlint --version"];
      systems = ["x86_64-linux"];
      reason = "a gradle build needs network, and nixpkgs builds android-cli for x86_64-linux and aarch64-darwin only";
      welcomeText = ''
        # android-kotlin

        Dev environment for Android with Kotlin, Jetpack Compose and Google's
        Android CLI. This template ships no project — `android create`
        generates it, so you start from Google's current AGP and Compose.

        A flake only sees files that git tracks, so initialise the repository
        before entering the shell:

        ```
        git init && git add -A
        nix develop                          # or: direnv allow
        android create --name="My App" -o myapp
        ```

        `android create` refuses a non-empty directory, which is why the
        project goes in a subdirectory. `README.md` covers the emulator, the
        deploy loop, the Neovim and Android Studio workflows, and why the SDK
        is not pinned here.
      '';
    };

    cpp = {
      description = "Dev environment for C/C++";
      kind = "devenv";
      tier = "build";
      smoke = ["cmake --version" "clangd --version"];
    };

    cpp-prod = {
      description = "Dev environment for production C/C++";
      kind = "devenv";
      tier = "build";
      smoke = ["cmake --version" "clangd --version" "clang-tidy --version" "gcovr --version"];
    };

    cpp-prod-modern = {
      description = "Dev environment for production C++ with modules";
      kind = "devenv";
      tier = "build";
      smoke = ["cmake --version" "clangd --version" "gcovr --version"];
    };

    cpp-simple = {
      description = "Dev environment for learning C++ with a plain Makefile";
      tier = "build";
      smoke = ["make --version" "clangd --version" "cpplint --version"];
    };

    devenv = {
      description = "Minimal devenv environment to fill in";
      kind = "devenv";
      tier = "shell";
      reason = "intentionally an empty stub; there is nothing to build or test";
    };

    devenv-postgres = {
      description = "devenv environment with a local PostgreSQL service";
      kind = "devenv";
      tier = "build";
      smoke = ["psql --version" "pg_isready --version"];
    };

    dotnet = {
      description = "Dev environment for .NET, with F# tooling";
      tier = "shell";
      smoke = ["dotnet --version"];
      reason = "packages.default needs a project scaffolded by the user, plus a generated nix/deps.json";
    };

    dotnet-react-postgres = {
      description = "devenv environment for .NET and React with a local PostgreSQL";
      kind = "devenv";
      tier = "build";
      smoke = ["dotnet --version" "node --version" "psql --version"];
    };

    go-react-postgres = {
      description = "devenv environment for Go and React with a local PostgreSQL";
      kind = "devenv";
      tier = "build";
      smoke = ["go version" "node --version" "psql --version"];
    };

    python = {
      description = "Dev environment for Python with uv, ruff and mypy";
      tier = "build";
      smoke = ["python3 --version" "uv --version" "ruff --version"];
    };

    rust = {
      description = "Dev environment for a minimal production-ready Rust project";
      tier = "build";
      smoke = ["cargo --version" "clippy-driver --version"];
    };

    shell = {
      description = "Minimal dev shell to fill in";
      tier = "shell";
      reason = "intentionally an empty stub; there is nothing to build or smoke-test";
    };

    ts-node = {
      description = "Dev environment for Node.js with TypeScript";
      tier = "build";
      smoke = ["node --version" "npm --version"];
    };

    typst = {
      description = "Dev environment for Typst documents";
      tier = "shell";
      smoke = ["typst --version"];
      reason = "dev-shell-only template; there is no package output to build";
    };
  };
}
