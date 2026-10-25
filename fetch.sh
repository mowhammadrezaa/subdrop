#!/usr/bin/env bash
set -euo pipefail

# SubDrop: download subtitles next to each video as <name>.srt (UTF-8).
# Default language: Persian (fa). Override: SUBDROP_LANG=en ./fetch.sh ...

# Finder / GUI apps use a minimal PATH — Homebrew tools are otherwise invisible.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"

PYTHON3=""
for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if [[ -x "$candidate" ]]; then
    PYTHON3="$candidate"
    break
  fi
done

SUBLIMINAL_BIN=""
for candidate in /opt/homebrew/bin/subliminal /usr/local/bin/subliminal; do
  if [[ -x "$candidate" ]]; then
    SUBLIMINAL_BIN="$candidate"
    break
  fi
done

CONFIG="${HOME}/.config/subdrop/config"
if [[ -z "${SUBDROP_LANG:-}" && -f "$CONFIG" ]]; then
  SUBDROP_LANG="$(grep -E '^SUBDROP_LANG=' "$CONFIG" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d ' "')"
fi
LANG_CODE="${SUBDROP_LANG:-fa}"
VIDEO_EXTS='mkv mp4 m4v mov avi webm ts m2ts'

notify() {
  /usr/bin/osascript -e "display notification $(printf '%q' "$2") with title $(printf '%q' "$1")" 2>/dev/null || true
}

subliminal_cmd() {
  if [[ -n "$SUBLIMINAL_BIN" ]]; then
    "$SUBLIMINAL_BIN" "$@"
  elif command -v subliminal >/dev/null 2>&1; then
    subliminal "$@"
  elif [[ -n "$PYTHON3" ]] && "$PYTHON3" -m subliminal --help >/dev/null 2>&1; then
    "$PYTHON3" -m subliminal "$@"
  else
    return 127
  fi
}

ensure_subliminal() {
  if subliminal_cmd download --help >/dev/null 2>&1; then
    return 0
  fi
  notify "SubDrop failed" "subliminal not found — run in Terminal: brew install python3; pip3 install subliminal"
  return 1
}

normalize_srt() {
  local srt="$1"
  [[ -f "$srt" ]] || return 1
  "${PYTHON3:-python3}" - "$srt" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8-sig")
p.write_text(text, encoding="utf-8", newline="\n")
PY
}

process_video() {
  local video="$1"
  if [[ ! -f "$video" ]]; then
    notify "SubDrop" "Not a file: $(basename "$video")"
    return 1
  fi

  local dir base ext
  dir="$(cd "$(dirname "$video")" && pwd)"
  base="$(basename "$video")"
  ext="${base##*.}"
  ext_lower="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  case " $VIDEO_EXTS " in
    *" $ext_lower "*) ;;
    *)
      notify "SubDrop" "Skipped (not a video): $base"
      return 0
      ;;
  esac

  local name="${base%.*}"
  local out="$dir/$name.srt"

  notify "SubDrop" "Downloading ${LANG_CODE} subs for ${base}..."

  if ! subliminal_cmd download -f -l "$LANG_CODE" \
    -p opensubtitlescom -p opensubtitles \
    -e utf-8 -s "$video" >/tmp/subdrop-last.log 2>&1; then
    notify "SubDrop failed" "$base — see /tmp/subdrop-last.log"
    return 1
  fi

  # -s writes <name>.srt; some providers still emit <name>.<lang>.srt
  local alt="$dir/$name.$LANG_CODE.srt"
  if [[ ! -f "$out" && -f "$alt" ]]; then
    mv -f "$alt" "$out"
  fi

  if [[ ! -f "$out" ]]; then
    notify "SubDrop failed" "No subtitle found for $base"
    return 1
  fi

  normalize_srt "$out"
  [[ -f "$alt" && "$alt" != "$out" ]] && rm -f "$alt"

  notify "SubDrop" "Saved $(basename "$out")"
  return 0
}

collect_videos() {
  local arg="$1"
  if [[ -d "$arg" ]]; then
    find "$arg" -maxdepth 3 -type f \( \
      -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' \
      -o -iname '*.avi' -o -iname '*.webm' -o -iname '*.ts' -o -iname '*.m2ts' \
    \) 2>/dev/null
  else
    printf '%s\n' "$arg"
  fi
}

main() {
  [[ $# -gt 0 ]] || {
    notify "SubDrop" "Drop video files onto the SubDrop app."
    exit 0
  }

  ensure_subliminal || exit 1

  local ok=0 fail=0
  while [[ $# -gt 0 ]]; do
    while IFS= read -r video; do
      [[ -n "$video" ]] || continue
      if process_video "$video"; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
      fi
    done < <(collect_videos "$1")
    shift
  done

  if [[ $ok -gt 0 && $fail -eq 0 ]]; then
    notify "SubDrop" "Done — $ok file(s)."
  elif [[ $fail -gt 0 ]]; then
    notify "SubDrop" "Finished — $ok ok, $fail failed."
    exit 1
  fi
}

main "$@"
