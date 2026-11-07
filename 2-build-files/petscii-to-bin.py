#!/usr/bin/env python3
"""Convert comma-separated decimal byte values to a binary file."""

import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    try:
        # PETSCII exports can include // comments and a trailing comma.
        source = "\n".join(
            line.split("//", 1)[0] for line in args.input.read_text().splitlines()
        )
        fields = source.strip().removesuffix(",").split(",")
        data = bytearray()
        for index, field in enumerate(fields, start=1):
            try:
                value = int(field.strip(), 10)
            except ValueError:
                parser.error(f"value {index} is not a decimal integer: {field!r}")
            if not 0 <= value <= 255:
                parser.error(f"value {index} is outside 0–255: {value}")
            data.append(value)
        args.output.write_bytes(data)
    except OSError as error:
        parser.error(str(error))

    print(f"Wrote {len(data)} bytes to {args.output}")


if __name__ == "__main__":
    main()
