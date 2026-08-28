#!/usr/bin/env python3
"""Generate ZIP lists and crawl ACT centers for multiple states."""

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def run(command):
    print("$", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--state",
        action="append",
        dest="states",
        required=True,
        help="Two-letter state code; repeat for multiple states, e.g. --state WA --state OR",
    )
    parser.add_argument("--min-delay", type=float, default=1.0)
    parser.add_argument("--max-delay", type=float, default=6.0)
    args = parser.parse_args()

    states = []
    for state in args.states:
        state = state.upper()
        if len(state) != 2 or not state.isalpha():
            raise SystemExit(f"Invalid state code: {state}")
        if state not in states:
            states.append(state)

    for state in states:
        zip_file = ROOT / f"zips-{state.lower()}.txt"
        output = ROOT / "data" / f"centers-{state.lower()}-simple.json"
        run([
            sys.executable,
            "generate_wa_zips.py",
            "--state", state,
            "--output", str(zip_file),
        ])
        run([
            sys.executable,
            "crawl_centers_simple.py",
            "--state", state,
            "--zip-file", str(zip_file),
            "--min-delay", str(args.min_delay),
            "--max-delay", str(args.max_delay),
            "--output", str(output),
        ])


if __name__ == "__main__":
    main()
