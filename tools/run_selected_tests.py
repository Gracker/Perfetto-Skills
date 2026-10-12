#!/usr/bin/env python3
"""Run explicit unittest targets and reject empty selections."""

from pathlib import Path
import sys
import unittest


def run_selected_tests(targets: list[str]) -> int:
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromNames(targets)
    if loader.errors or suite.countTestCases() == 0:
        print("test selection is invalid or empty", file=sys.stderr)
        for error in loader.errors:
            print(error, file=sys.stderr)
        return 2
    result = unittest.TextTestRunner().run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    raise SystemExit(run_selected_tests(sys.argv[1:]))
