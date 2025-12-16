#!/usr/bin/env python3
"""Simple test runner to verify tests work correctly."""

import sys
import subprocess
from pathlib import Path

def main():
    """Run pytest and display results."""
    project_root = Path(__file__).parent
    tests_dir = project_root / "tests"

    if not tests_dir.exists():
        print(f"Error: Tests directory not found at {tests_dir}")
        return 1

    print("=" * 70)
    print("Running Aare Edge Test Suite")
    print("=" * 70)
    print(f"Project root: {project_root}")
    print(f"Tests directory: {tests_dir}")
    print()

    # Run pytest
    cmd = [
        sys.executable,
        "-m",
        "pytest",
        str(tests_dir),
        "-v",
        "--tb=short",
        "--color=yes"
    ]

    print(f"Command: {' '.join(cmd)}")
    print("=" * 70)
    print()

    try:
        result = subprocess.run(cmd, cwd=project_root)
        return result.returncode
    except FileNotFoundError:
        print("Error: pytest not installed. Install with: pip install pytest")
        return 1

if __name__ == "__main__":
    sys.exit(main())
