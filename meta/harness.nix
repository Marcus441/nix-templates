# Exposes the registry to the shell world. scripts/test-template.sh reads tiers
# from here rather than parsing Nix, so meta/templates.nix stays the single
# source of truth (Inv. 2).
{config, ...}: {
  perSystem = {pkgs, ...}: {
    packages.registry-json =
      pkgs.writeText "registry.json"
      (builtins.toJSON config.templates);

    apps.test = {
      type = "app";
      program = "${pkgs.writeShellApplication {
        name = "test-template";
        runtimeInputs = [pkgs.jq pkgs.git];
        text = builtins.readFile ../scripts/test-template.sh;
      }}/bin/test-template";
      meta.description = "Instantiate each template in a sandbox and test it at its declared tier";
    };
  };
}
