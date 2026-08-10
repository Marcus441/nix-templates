# Templates iterate systems without flake-utils

**Why:** every template used to carry `flake-utils` purely to call
`eachDefaultSystem`. That is a second input the consumer fetches and locks
before their first `nix develop`, in exchange for one function that
`nixpkgs.lib.genAttrs` already provides. Templates depend on nixpkgs anyway, so
flake-utils' independence from it buys nothing here.

The stronger reason is `eachDefaultSystem` itself. It generates outputs for a
fixed system list that the template has no say in — so `android-kotlin`, which
the registry restricts to `x86_64-linux`, advertised all four default systems
and only baked `abiVersions = ["x86_64"]`. The narrowing existed solely in
`meta/templates.nix`. Writing the list in the flake makes the artifact
self-describing, and `checks.flake-inputs` renders the expected line from the
registry and greps for it, so the two cannot drift.

**Breaks:** four lines of helper are now duplicated in all eleven templates.
Inv. 1 forbids factoring them out — a template is copied verbatim and cannot
import anything — so this is a permanent, deliberate duplication, held in sync
by `checks.flake-inputs` rather than by abstraction. Anyone reading two
templates side by side will see the same four lines twice; that is the design,
not an oversight.

A second cost: `forAllSystems` passes `pkgs`, not `system`. Templates that need
`self.packages.<system>` index with `pkgs.system` instead. This keeps the helper
one-argument across all eleven files, at the price of an idiom that is slightly
less obvious than the `system` variable `eachDefaultSystem` used to bind.

**Also:** the helper is the shape the wider ecosystem has converged on —
`nixpkgs.lib.genAttrs` over an explicit list — and it removes a class of mistake
flake-utils cannot catch, where a non-system-specific output (`overlays`,
`nixosModules`) ends up nested under a system, or a system-specific one ends up
nested twice.

**Rejected: a shared helper the templates import.** Inv. 1 makes it impossible,
not merely discouraged: `nix flake init` copies one directory, and any `../lib`
reference would dangle in every generated project.

**Rejected: flake-parts inside a template.** Inv. 4. The registry uses it; a
generated project should not inherit a framework it did not ask for, and a
template has to be readable by someone who has never seen this repo.

**Rejected: keeping flake-utils and switching to `eachSystem` with an explicit
list.** It fixes the system-list problem but keeps the input, which was the
other half of the cost. Nothing then remains that nixpkgs does not already do.
