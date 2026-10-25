"""Cross-platform subtitle download core for SubDrop."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

VIDEO_EXTENSIONS = {".mkv", ".mp4", ".m4v", ".mov", ".avi", ".webm", ".ts", ".m2ts"}
LOG_PATH = Path(os.environ.get("SUBDROP_LOG", Path(tempfile.gettempdir()) / "subdrop-last.log"))
CRASH_LOG_PATH = Path(tempfile.gettempdir()) / "subdrop-crash.log"
TRACE_LOG_PATH = Path(tempfile.gettempdir()) / "subdrop-trace.log"

_subliminal_lock = threading.Lock()
_subliminal_ready = False


def trace(msg: str) -> None:
    """Append-only log safe from any thread (windnd runs off the tk main thread)."""
    import datetime

    line = f"{datetime.datetime.now(datetime.timezone.utc).isoformat()} {msg}\n"
    try:
        TRACE_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with TRACE_LOG_PATH.open("a", encoding="utf-8", errors="replace") as f:
            f.write(line)
            f.flush()
    except OSError:
        pass


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


def _is_frozen() -> bool:
    return getattr(sys, "frozen", False)


def _download_cli_args(lang_code: str, video: Path) -> list[str]:
    return [
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


def _write_log(text: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text(text, encoding="utf-8", errors="replace")


def _append_log(line: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8", errors="replace") as f:
        f.write(line)
        if not line.endswith("\n"):
            f.write("\n")
        f.flush()


def _run_subliminal_inprocess(args: list[str]) -> None:
    """Run subliminal inside this EXE (babelfish data must be bundled; see packaging spec)."""
    from click.testing import CliRunner
    from subliminal.cli.cli import subliminal

    trace(f"subliminal inprocess args={args}")
    _append_log(f"inprocess: {' '.join(args)}")
    runner = CliRunner()
    result = runner.invoke(subliminal, args, catch_exceptions=False)
    output = result.output or ""
    if result.exception:
        import traceback as _tb

        output += "\n" + "".join(
            _tb.format_exception(type(result.exception), result.exception, result.exception.__traceback__)
        )
    _append_log(output)
    if result.exit_code != 0:
        tail = output.strip().splitlines()[-16:]
        raise RuntimeError("\n".join(tail) or f"subliminal failed (exit {result.exit_code})")


def subliminal_download_argv(lang_code: str, video: Path) -> list[str]:
    tail = _download_cli_args(lang_code, video)
    exe = shutil.which("subliminal")
    if exe:
        return [exe, *tail]
    return [sys.executable, "-m", "subliminal", *tail]


def _subprocess_kwargs() -> dict:
    kwargs: dict = {}
    if sys.platform == "win32":
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
    return kwargs


def ensure_subliminal() -> None:
    global _subliminal_ready
    if _is_frozen():
        if _subliminal_ready:
            return
        with _subliminal_lock:
            if _subliminal_ready:
                return
            try:
                from subliminal.cli.cli import subliminal  # noqa: F401
            except Exception as e:
                trace(f"ensure_subliminal import failed: {e!r}")
                raise RuntimeError(f"subliminal is not available in this SubDrop build: {e}") from e
            _subliminal_ready = True
            trace("ensure_subliminal import ok")
        return

    probe = find_subliminal_command() + ["download", "--help"]
    try:
        subprocess.run(probe, capture_output=True, check=True, timeout=60, **_subprocess_kwargs())
    except (subprocess.CalledProcessError, FileNotFoundError, OSError) as e:
        raise RuntimeError("subliminal is not installed. Run: pip install subliminal") from e


def find_subliminal_command() -> list[str]:
    exe = shutil.which("subliminal")
    if exe:
        return [exe]
    return [sys.executable, "-m", "subliminal"]


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

    if _is_frozen():
        _append_log(f"video: {video}")
        _run_subliminal_inprocess(_download_cli_args(lang_code, video))
    else:
        cmd = subliminal_download_argv(lang_code, video)
        with LOG_PATH.open("w", encoding="utf-8") as log:
            proc = subprocess.run(
                cmd,
                stdout=log,
                stderr=subprocess.STDOUT,
                **_subprocess_kwargs(),
            )
        if proc.returncode != 0:
            tail = LOG_PATH.read_text(encoding="utf-8", errors="replace").splitlines()[-12:]
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
    trace(f"process_paths lang={lang_code} n={len(paths)}")
    _write_log(f"SubDrop process_paths lang={lang_code} paths={len(paths)}\n")
    ensure_subliminal()
    trace("ensure_subliminal ok")
    _append_log("ensure_subliminal ok")
    ok, fail = 0, 0
    messages: list[str] = []
    for raw in paths:
        for video in collect_videos(raw):
            try:
                srt = process_video(video, lang_code)
                ok += 1
                messages.append(f"Saved {srt}")
            except Exception as e:
                fail += 1
                messages.append(f"{video.name}: {e}")
    return ok, fail, messages
