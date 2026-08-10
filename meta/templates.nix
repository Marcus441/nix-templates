# The registry. Adding an entry here is what publishes a template.
# Field semantics and how to choose a tier: .claude/rules/registry.md.
{
  templates = {
    android-kotlin = {
      description = "Dev environment for Android with Kotlin and Jetpack Compose (nixpkgs androidenv)";
      tier = "eval";
      locked = true;
      unfree = true;
      systems = ["x86_64-linux"];
      reason = "unfree Android SDK, and a gradle build needs network";
    };

    cpp = {
      description = "Dev environment for C/C++";
      tier = "build";
      smoke = ["cmake --version" "clangd --version"];
    };

    cpp-jetson = {
      description = "Dev environment for C/C++ on the Jetson platform";
      tier = "eval";
      locked = true;
      unfree = true;
      broken = true;
      reason = "packages.arm64.app is a nested attrset, which the flake schema rejects (issue #1)";
    };

    cpp-modern = {
      description = "Dev environment for modern C++ with modules support";
      tier = "build";
      smoke = ["cmake --version" "clangd --version"];
    };

    dotnet = {
      description = "Dev environment with dotnet sdk and runtime";
      tier = "shell";
      unfree = true;
      smoke = ["dotnet --version"];
      reason = "packages.default needs a project scaffolded by the user, plus a generated nix/deps.nix";
    };

    node = {
      description = "Dev environment for node.js";
      tier = "shell";
      smoke = ["node --version" "npm --version"];
      reason = "dev-shell-only template; there is no package output to build";
    };

    node-rest-api = {
      description = "Dev environment for a node.js rest api";
      tier = "shell";
      smoke = ["node --version" "npm --version"];
      reason = "dev-shell-only template; there is no package output to build";
    };

    python-jetson = {
      description = "Dev Environment for Python on the jetson platform";
      tier = "eval";
      locked = true;
      unfree = true;
      broken = true;
      reason = "packages.arm64.app is a nested attrset, and pyproject.toml is empty (issue #1)";
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

    typst = {
      description = "Dev environment for typst documents";
      tier = "shell";
      smoke = ["typst --version"];
      reason = "dev-shell-only template; there is no package output to build";
    };
  };
}
