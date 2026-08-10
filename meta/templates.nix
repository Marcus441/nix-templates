# The registry. Adding an entry here is what publishes a template.
# Field semantics and how to choose a tier: .claude/rules/registry.md.
{
  templates = {
    android-kotlin = {
      description = "Dev environment for Android with Kotlin and Jetpack Compose (nixpkgs androidenv)";
      tier = "eval";
      locked = true;
      systems = ["x86_64-linux"];
      reason = "unfree Android SDK, and a gradle build needs network";
    };

    cpp = {
      description = "Dev environment for C/C++";
      tier = "build";
      smoke = ["cmake --version" "clangd --version"];
    };

    cpp-prod = {
      description = "Dev environment for production C/C++";
      tier = "build";
      smoke = ["cmake --version" "clangd --version" "clang-tidy --version" "gcovr --version"];
    };

    cpp-prod-modern = {
      description = "Dev environment for production C++ with modules";
      tier = "build";
      smoke = ["cmake --version" "clangd --version" "gcovr --version"];
    };

    cpp-simple = {
      description = "Dev environment for learning C++ with a plain Makefile";
      tier = "build";
      smoke = ["make --version" "clangd --version" "cpplint --version"];
    };

    dotnet = {
      description = "Dev environment with dotnet sdk and runtime";
      tier = "shell";
      smoke = ["dotnet --version"];
      reason = "packages.default needs a project scaffolded by the user, plus a generated nix/deps.nix";
    };

    node = {
      description = "Dev environment for Node.js";
      tier = "build";
      smoke = ["node --version" "npm --version"];
    };

    node-rest-api = {
      description = "Dev environment for a Node.js REST API";
      tier = "build";
      smoke = ["node --version" "npm --version"];
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
      description = "Dev environment for Typst documents";
      tier = "shell";
      smoke = ["typst --version"];
      reason = "dev-shell-only template; there is no package output to build";
    };
  };
}
