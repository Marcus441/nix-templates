# flake-parts at the root

**Why:** the root flake had zero inputs and only a `templates` attrset, so it
had no `checks`, no formatter and no way to grow one. `perSystem` is what makes
a `checks` output practical, and two templates were shipping broken with nothing
to notice.

**Breaks:** a consumer's first command now costs a fetch. Nix resolves every
root input before evaluating `outputs`, so `nix flake init -t
github:Marcus441/nix-templates#shell` pulls flake-parts and nixpkgs before
printing anything. Committing the root lock makes that deterministic but does
not remove it. This is a real regression for the repo's actual product, paid to
make the product testable.

**Also:** the only structural escape is a second flake (`dev/flake.nix`) holding
the meta layer. Rejected — it would have to reach the templates as `path:`
inputs, and a parent lock supersedes a child's committed `flake.lock`, so the
three locked templates would be tested at pins no consumer ever sees. It also
freezes the eight unlocked templates, which defeats the scheduled drift run.

**Not adopted: the dendritic pattern.** `~/.dotfiles/flake/` uses it, and it
does not transfer. Its value is merge semantics — many files → one aspect, one
file → many aspects. A template maps 1:1 to exactly one registry entry, so
there is nothing to merge; adopting it would turn a list-edit into a
file-create and add an `import-tree` input for that alone. Revisit if templates
ever contribute a second output class.
