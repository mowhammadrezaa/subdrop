#!/usr/bin/env python3
"""SubDrop CLI — download subtitles for videos (all platforms)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from subdrop.core import process_paths, read_default_language, write_default_language


def main() -> int:
    parser = argparse.ArgumentParser(description="Download subtitles next to video files (UTF-8 .srt).")
    parser.add_argument("paths", nargs="+", type=Path, help="Video files or folders")
    parser.add_argument("-l", "--language", help="Subtitle language code (e.g. fa, en)")
    args = parser.parse_args()

    lang = args.language or read_default_language()
    if args.language:
        write_default_language(lang)

    ok, fail, messages = process_paths(args.paths, lang)
    for line in messages:
        print(line)
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
