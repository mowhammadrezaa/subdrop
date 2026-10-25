#!/usr/bin/env python3
"""Build languages.json from the OpenSubtitles language table."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUNDLED_TABLE = ROOT / "data" / "opensubtitles_languages.txt"


def load_table_lines() -> list[str]:
    if BUNDLED_TABLE.is_file():
        return BUNDLED_TABLE.read_text(encoding="utf-8").splitlines()
    try:
        from importlib.resources import files as pkg_files

        data_path = pkg_files("babelfish").joinpath("data/opensubtitles_languages.txt")
        return data_path.read_text(encoding="utf-8").splitlines()
    except Exception as exc:
        raise SystemExit(
            f"Missing {BUNDLED_TABLE} and babelfish is not installed ({exc})"
        ) from exc


entries: list[dict[str, str]] = []
seen: set[str] = set()

for line in load_table_lines()[1:]:
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 5:
        continue
    idsub, iso, name, upload, web = parts[0], parts[1], parts[2], parts[3], parts[4]
    if not name:
        continue
    if upload != "1" and web != "1":
        continue
    code = iso if iso else idsub
    if not code or code in seen:
        continue
    seen.add(code)
    entries.append({"code": code, "name": name})

entries.sort(key=lambda e: e["name"].lower())

out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "languages.json"
out.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(entries)} languages to {out}")
