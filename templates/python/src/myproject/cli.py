"""Command-line entry point."""

import argparse
from collections.abc import Sequence


def greet(name: str) -> str:
    """Return a greeting for ``name``."""
    return f"Hello, {name}!"


def main(argv: Sequence[str] | None = None) -> int:
    """Parse ``argv``, print a greeting, and return the process exit code."""
    parser = argparse.ArgumentParser(prog="myproject", description="Greet someone.")
    parser.add_argument("name", nargs="?", default="world", help="who to greet")
    args = parser.parse_args(argv)
    print(greet(args.name))
    return 0
