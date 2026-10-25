#!/usr/bin/env python3
"""Build languages.json for SubDrop from OpenSubtitles language table."""
import json
import sys
from pathlib import Path

try:
    from importlib.resources import files as pkg_files
    data_path = pkg_files("babelfish").joinpath("data/opensubtitles_languages.txt")
    lines = data_path.read_text(encoding="utf-8").splitlines()
except Exception:
    # fallback when babelfish path is known
    data_path = Path(
        "/opt/homebrew/lib/python3.14/site-packages/babelfish/data/opensubtitles_languages.txt"
    )
    lines = data_path.read_text(encoding="utf-8").splitlines()

entries: list[dict[str, str]] = []
seen: set[str] = set()

for line in lines[1:]:
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

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("languages.json")
out.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(entries)} languages to {out}")
