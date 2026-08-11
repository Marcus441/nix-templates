"""Support ``python -m myproject``."""

import sys

from myproject.cli import main

if __name__ == "__main__":
    sys.exit(main())
