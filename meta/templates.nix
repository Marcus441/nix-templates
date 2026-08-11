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
