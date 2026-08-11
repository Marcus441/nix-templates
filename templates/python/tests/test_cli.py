"""Tests for the greeting CLI."""

import pytest

from myproject import greet
from myproject.cli import main


def test_greet_uses_the_name() -> None:
    assert greet("Ada") == "Hello, Ada!"


@pytest.mark.parametrize(
    ("argv", "expected"),
    [([], "Hello, world!\n"), (["Ada"], "Hello, Ada!\n")],
)
def test_main_prints_a_greeting(
    argv: list[str],
    expected: str,
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert main(argv) == 0
    assert capsys.readouterr().out == expected
