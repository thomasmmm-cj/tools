#!/usr/bin/env python3
"""Generate postal ZIP codes for a US state from the public GeoNames file."""

import argparse
import csv
import io
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile


URL = "https://download.geonames.org/export/zip/US.zip"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", default="WA", help="Two-letter state code, e.g. OR")
    parser.add_argument("--output", help="Output ZIP file")
    args = parser.parse_args()
    state = args.state.upper()
    output = args.output or f"zips-{state.lower()}.txt"

    with urlopen(URL, timeout=120) as response:
        archive = ZipFile(io.BytesIO(response.read()))

    zips = set()
    with archive.open("US.txt") as handle:
        reader = csv.reader(io.TextIOWrapper(handle, encoding="utf-8"), delimiter="\t")
        for row in reader:
            if len(row) < 5 or row[0] != "US" or row[4] != state:
                continue
            zip_code = row[1].split("-")[0]
            if len(zip_code) == 5 and zip_code.isdigit():
                zips.add(zip_code)

    zips = sorted(zips)
    Path(output).write_text(
        f"# {state} postal ZIP codes from GeoNames\n" + "\n".join(zips) + "\n"
    )
    print(f"Wrote {len(zips)} ZIP codes to {output}")


if __name__ == "__main__":
    main()
