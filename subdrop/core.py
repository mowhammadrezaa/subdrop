"""Cross-platform subtitle download core for SubDrop."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VIDEO_EXTENSIONS = {".mkv", ".mp4", ".m4v", ".mov", ".avi", ".webm", ".ts", ".m2ts"}
LOG_PATH = Path(os.environ.get("SUBDROP_LOG", Path(tempfile.gettempdir()) / "subdrop-last.log"))


def config_path() -> Path:
    return Path.home() / ".config" / "subdrop" / "config"


def read_default_language() -> str:
    env = os.environ.get("SUBDROP_LANG")
    if env:
        return env.strip()
    cfg = config_path()
    if cfg.is_file():
        for line in cfg.read_text(encoding="utf-8").splitlines():
            if line.startswith("SUBDROP_LANG="):
                return line.split("=", 1)[1].strip().strip('"')
    return "fa"


def write_default_language(code: str) -> None:
    cfg = config_path()
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(f"# Updated by SubDrop\nSUBDROP_LANG={code}\n", encoding="utf-8")


def resource_languages_json() -> Path:
    if getattr(sys, "frozen", False):
        base = Path(sys._MEIPASS)  # type: ignore[attr-defined]
    else:
        base = Path(__file__).resolve().parent.parent
    for candidate in (base / "languages.json", base / "Resources" / "languages.json"):
        if candidate.is_file():
            return candidate
    return base / "languages.json"


def load_languages() -> list[dict[str, str]]:
    path = resource_languages_json()
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    return [
        {"code": "fa", "name": "Persian"},
        {"code": "en", "name": "English"},
        {"code": "fr", "name": "French"},
    ]


def normalize_srt(path: Path) -> None:
    text = path.read_text(encoding="utf-8-sig")
    path.write_text(text, encoding="utf-8", newline="\n")


def find_subliminal_command() -> list[str]:
    exe = shutil.which("subliminal")
    if exe:
        return [exe]
    return [sys.executable, "-m", "subliminal"]


def ensure_subliminal() -> None:
    cmd = find_subliminal_command() + ["download", "--help"]
    try:
        subprocess.run(cmd, capture_output=True, check=True, timeout=30)
    except (subprocess.CalledProcessError, FileNotFoundError, OSError) as e:
        raise RuntimeError("subliminal is not installed. Run: pip install subliminal") from e


def collect_videos(path: Path) -> list[Path]:
    if path.is_dir():
        found: list[Path] = []
        for root, _dirs, files in os.walk(path):
            depth = len(Path(root).relative_to(path).parts)
            if depth > 3:
                continue
            for name in files:
                p = Path(root) / name
                if p.suffix.lower() in VIDEO_EXTENSIONS:
                    found.append(p.resolve())
        return found
    if path.is_file():
        return [path.resolve()]
    return []


def process_video(video: Path, lang_code: str) -> Path:
    if video.suffix.lower() not in VIDEO_EXTENSIONS:
        raise ValueError(f"Not a supported video: {video.name}")

    out = video.with_suffix(".srt")
    alt = video.parent / f"{video.stem}.{lang_code}.srt"

    cmd = find_subliminal_command() + [
        "download",
        "-f",
        "-l",
        lang_code,
        "-p",
        "opensubtitlescom",
        "-p",
        "opensubtitles",
        "-e",
        "utf-8",
        "-s",
        str(video),
    ]

    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("w", encoding="utf-8") as log:
        proc = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT)

    if proc.returncode != 0:
        tail = LOG_PATH.read_text(encoding="utf-8", errors="replace").splitlines()[-6:]
        raise RuntimeError("\n".join(tail) or f"subliminal failed (code {proc.returncode})")

    if not out.is_file() and alt.is_file():
        shutil.move(str(alt), str(out))

    if not out.is_file():
        raise FileNotFoundError(f"No subtitle found for {video.name}")

    normalize_srt(out)
    if alt.is_file() and alt != out:
        alt.unlink(missing_ok=True)
    return out


def process_paths(paths: list[Path], lang_code: str) -> tuple[int, int, list[str]]:
    ensure_subliminal()
    ok, fail = 0, 0
    messages: list[str] = []
    for raw in paths:
        for video in collect_videos(raw):
            try:
                srt = process_video(video, lang_code)
                ok += 1
                messages.append(f"Saved {srt.name}")
            except Exception as e:
                fail += 1
                messages.append(f"{video.name}: {e}")
    return ok, fail, messages
