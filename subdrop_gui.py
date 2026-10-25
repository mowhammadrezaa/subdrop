#!/usr/bin/env python3
"""SubDrop GUI for Windows and Linux (tkinter)."""
from __future__ import annotations

import sys

if sys.platform == "win32" and getattr(sys, "frozen", False):
    import multiprocessing

    multiprocessing.freeze_support()

# PyInstaller: child process runs subliminal without loading the GUI (see core.py).
if __name__ == "__main__" and len(sys.argv) >= 2 and sys.argv[1] == "--subliminal":
    import traceback as _tb

    sys.argv = ["subliminal"] + sys.argv[2:]
    try:
        from subliminal.cli.cli import cli

        cli()
    except SystemExit as exc:
        raise SystemExit(exc.code if isinstance(exc.code, int) else 1) from None
    except Exception:
        _tb.print_exc()
        raise SystemExit(1) from None
    raise SystemExit(0)

import queue
import threading
import traceback
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from subdrop.core import (  # noqa: E402
    CRASH_LOG_PATH,
    CREATOR_EMAIL,
    LOG_PATH,
    TRACE_LOG_PATH,
    load_languages,
    process_paths,
    read_default_language,
    trace,
    write_default_language,
)


def _decode_dropped_path(raw: object) -> Path:
    if isinstance(raw, bytes):
        text = None
        for encoding in ("utf-8", "mbcs", "latin-1"):
            try:
                text = raw.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        text = (text or raw.decode("latin-1", errors="replace")).strip().strip("\x00")
    else:
        text = str(raw).strip().strip("\x00")
    if text.startswith("{") and text.endswith("}"):
        text = text[1:-1]
    return Path(text)


def install_exception_hooks() -> None:
    import faulthandler

    try:
        CRASH_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        fault_file = CRASH_LOG_PATH.open("a", encoding="utf-8")
        faulthandler.enable(file=fault_file, all_threads=True)
    except OSError:
        faulthandler.enable()

    def log_exc(exc_type, exc, tb) -> None:
        try:
            with CRASH_LOG_PATH.open("a", encoding="utf-8") as f:
                f.write("".join(traceback.format_exception(exc_type, exc, tb)))
                f.flush()
        except OSError:
            pass

    sys.excepthook = log_exc
    if hasattr(threading, "excepthook"):
        threading.excepthook = lambda args: log_exc(args.exc_type, args.exc_value, args.exc_traceback)  # type: ignore[misc]


class SubDropApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("SubDrop")
        self.minsize(520, 480)
        self.geometry("560x520")

        self.languages = load_languages()
        self.lang_code = read_default_language()
        self.lang_name = self._name_for_code(self.lang_code)
        self.picker_open = False
        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *_: self._filter_languages())
        self.busy = False
        self._filtered: list[dict[str, str]] = []
        self._dnd_enabled = False
        self._drop_queue: queue.Queue[list[Path] | str] = queue.Queue()

        self._build_ui()
        self._register_dnd()
        self.after(150, self._poll_drop_queue)

    def _name_for_code(self, code: str) -> str:
        for item in self.languages:
            if item["code"] == code:
                return item["name"]
        return code

    def _build_ui(self) -> None:
        self.banner = tk.Frame(self, bg="#5b4fe8", padx=16, pady=14)
        self.banner.pack(fill=tk.X, padx=12, pady=(12, 6))

        tk.Label(
            self.banner,
            text="Subtitles will download in",
            fg="#e8e4ff",
            bg="#5b4fe8",
            font=("", 11, "bold"),
        ).pack(anchor="w")

        row = tk.Frame(self.banner, bg="#5b4fe8")
        row.pack(fill=tk.X, pady=(6, 0))

        self.lang_label = tk.Label(
            row, text=self.lang_name, fg="white", bg="#5b4fe8", font=("", 20, "bold")
        )
        self.lang_label.pack(side=tk.LEFT)

        self.code_label = tk.Label(
            row, text=self.lang_code.upper(), fg="white", bg="#6d62ec", padx=8, pady=2
        )
        self.code_label.pack(side=tk.LEFT, padx=(10, 0))

        self.toggle_btn = ttk.Button(row, text="Change language", command=self._toggle_picker)
        self.toggle_btn.pack(side=tk.RIGHT)

        self.picker_frame = tk.Frame(self, padx=12, pady=6)

        tk.Label(self.picker_frame, text="Search by language name or code").pack(anchor="w")
        ttk.Entry(self.picker_frame, textvariable=self.search_var).pack(fill=tk.X, pady=4)

        list_frame = tk.Frame(self.picker_frame)
        list_frame.pack(fill=tk.BOTH, expand=True)
        scroll = ttk.Scrollbar(list_frame)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.lang_list = tk.Listbox(list_frame, height=10, yscrollcommand=scroll.set)
        self.lang_list.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.config(command=self.lang_list.yview)
        self.lang_list.bind("<<ListboxSelect>>", self._on_lang_select)
        self._filter_languages()

        self.drop = tk.LabelFrame(self, text="Videos", padx=16, pady=16)
        self.drop.pack(fill=tk.BOTH, expand=True, padx=12, pady=6)

        self.drop_msg = tk.Label(
            self.drop,
            text="Drag and drop video files here\n(or use the button below)",
            justify=tk.CENTER,
            font=("", 13, "bold"),
        )
        self.drop_msg.pack(expand=True)

        tk.Label(
            self.drop,
            text="Drop as many files as you want. Each video gets a matching .srt beside it (UTF-8).",
            fg="gray",
            wraplength=480,
            justify=tk.CENTER,
        ).pack(pady=(0, 8))

        ttk.Button(self.drop, text="Choose video files…", command=self._pick_files).pack(pady=4)

        self.status = tk.Label(self, text="", fg="gray", wraplength=500)
        self.status.pack(fill=tk.X, padx=12, pady=(0, 4))
        self.status.config(text=f"Language: {self.lang_name} ({self.lang_code})")

        self.footer = tk.Label(
            self,
            text=f"Report issues: {CREATOR_EMAIL}",
            fg="gray",
            font=("", 9),
            cursor="hand2",
        )
        self.footer.pack(fill=tk.X, padx=12, pady=(0, 10))
        self.footer.bind("<Button-1>", self._open_creator_email)

    def _open_creator_email(self, _event: object = None) -> None:
        import webbrowser

        webbrowser.open(f"mailto:{CREATOR_EMAIL}")

    def _register_dnd(self) -> None:
        if sys.platform == "win32":
            try:
                import windnd  # type: ignore

                def on_drop(files: object) -> None:
                    # windnd calls this from a non-tk thread — never touch self.after() here.
                    trace(f"windnd on_drop files={files!r}")
                    try:
                        raw_list = list(files) if files is not None else []
                        paths = [_decode_dropped_path(raw) for raw in raw_list]
                        trace(f"windnd decoded paths={[str(p) for p in paths]}")
                        if paths:
                            self._drop_queue.put(list(paths))
                    except Exception as exc:
                        trace(f"windnd on_drop error: {exc!r}")
                        self._drop_queue.put(f"drop:{exc}")

                windnd.hook_dropfiles(self.drop, func=on_drop)
                self._dnd_enabled = True
                trace("windnd hooked on drop frame")
                return
            except Exception as exc:
                trace(f"windnd setup failed: {exc!r}")
            except Exception:
                pass

        if sys.platform != "win32":
            try:
                from tkinterdnd2 import DND_FILES  # type: ignore

                self.drop.drop_target_register(DND_FILES)
                self.drop.dnd_bind("<<Drop>>", self._on_drop)
                self._dnd_enabled = True
                return
            except (ImportError, tk.TclError):
                pass

        self.drop_msg.config(
            text="Use “Choose video files…” below\n(drag-and-drop unavailable in this build)"
        )

    def _poll_drop_queue(self) -> None:
        try:
            while True:
                item = self._drop_queue.get_nowait()
                if isinstance(item, str):
                    if item.startswith("drop:"):
                        messagebox.showerror("SubDrop", f"Could not read dropped files:\n{item[5:]}")
                    continue
                trace(f"main thread _run_jobs from queue n={len(item)}")
                self._run_jobs(item)
        except queue.Empty:
            pass
        self.after(150, self._poll_drop_queue)

    def _toggle_picker(self) -> None:
        if self.picker_open:
            self.picker_frame.pack_forget()
            self.picker_open = False
            self.toggle_btn.config(text="Change language")
        else:
            self.picker_frame.pack(fill=tk.BOTH, expand=True, after=self.banner)
            self.picker_open = True
            self.toggle_btn.config(text="Done")

    def _filter_languages(self) -> None:
        q = self.search_var.get().strip().lower()
        self.lang_list.delete(0, tk.END)
        self._filtered = []
        for item in self.languages:
            if q and q not in item["name"].lower() and q not in item["code"].lower():
                continue
            self.lang_list.insert(tk.END, f"{item['name']} ({item['code']})")
            self._filtered.append(item)

    def _on_lang_select(self, _event: object) -> None:
        sel = self.lang_list.curselection()
        if not sel:
            return
        item = self._filtered[sel[0]]
        self.lang_code = item["code"]
        self.lang_name = item["name"]
        write_default_language(self.lang_code)
        self.lang_label.config(text=self.lang_name)
        self.code_label.config(text=self.lang_code.upper())
        if self.picker_open:
            self._toggle_picker()
        self.status.config(text=f"Language: {self.lang_name} ({self.lang_code})")

    def _pick_files(self) -> None:
        paths = filedialog.askopenfilenames(
            title="Choose videos",
            filetypes=[
                ("Video", "*.mkv *.mp4 *.m4v *.mov *.avi *.webm *.ts *.m2ts"),
                ("All", "*.*"),
            ],
        )
        if paths:
            self._run_jobs([Path(p) for p in paths])

    def _on_drop(self, event: object) -> None:
        data = getattr(event, "data", "")
        paths = [Path(p) for p in self.tk.splitlist(data)]
        if paths:
            self._run_jobs(paths)

    def _run_jobs(self, paths: list[Path]) -> None:
        trace(f"_run_jobs busy={self.busy} paths={[str(p) for p in paths]}")
        if self.busy:
            return
        self.busy = True
        self.status.config(text="Working…")
        self.drop_msg.config(text="Downloading subtitles…")

        def work() -> None:
            trace("worker thread started")
            try:
                ok, fail, messages = process_paths(paths, self.lang_code)
                text = "\n".join(messages[-8:])
                log_hint = f"\n\nLog: {LOG_PATH}"
                if fail:
                    self.after(
                        0,
                        lambda: messagebox.showwarning(
                            "SubDrop", (text or "Some downloads failed.") + log_hint
                        ),
                    )
                elif ok:
                    self.after(
                        0,
                        lambda: messagebox.showinfo("SubDrop", text or f"Done — {ok} file(s)."),
                    )
                else:
                    self.after(0, lambda: messagebox.showwarning("SubDrop", "No videos processed."))
            except Exception as e:
                trace(f"worker exception: {e!r}")
                try:
                    with CRASH_LOG_PATH.open("a", encoding="utf-8") as f:
                        f.write(traceback.format_exc())
                        f.flush()
                except OSError:
                    pass
                self.after(
                    0,
                    lambda: messagebox.showerror(
                        "SubDrop",
                        f"{e}\n\nDetails: {LOG_PATH}\nCrash: {CRASH_LOG_PATH}",
                    ),
                )
            finally:
                self.after(0, self._idle)

        threading.Thread(target=work, daemon=True).start()

    def _idle(self) -> None:
        self.busy = False
        if self._dnd_enabled:
            self.drop_msg.config(text="Drag and drop video files here\n(or use the button below)")
        else:
            self.drop_msg.config(
                text="Use “Choose video files…” below\n(drag-and-drop unavailable in this build)"
            )
        self.status.config(text=f"Language: {self.lang_name} ({self.lang_code})")


def main() -> None:
    install_exception_hooks()
    try:
        LOG_PATH.write_text(f"SubDrop started argv={sys.argv!r}\n", encoding="utf-8")
        trace(f"SubDrop started argv={sys.argv!r} trace={TRACE_LOG_PATH}")
    except OSError:
        pass
    SubDropApp().mainloop()


if __name__ == "__main__":
    main()
