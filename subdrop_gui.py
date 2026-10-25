#!/usr/bin/env python3
"""SubDrop GUI for Windows and Linux (tkinter)."""
from __future__ import annotations

import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from subdrop.core import (  # noqa: E402
    load_languages,
    process_paths,
    read_default_language,
    write_default_language,
)


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

        self._build_ui()
        self._register_dnd()

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
        self.status.pack(fill=tk.X, padx=12, pady=(0, 10))
        self.status.config(text=f"Language: {self.lang_name} ({self.lang_code})")

    def _register_dnd(self) -> None:
        try:
            from tkinterdnd2 import DND_FILES  # type: ignore

            self.drop.drop_target_register(DND_FILES)
            self.drop.dnd_bind("<<Drop>>", self._on_drop)
        except ImportError:
            pass

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
        if self.busy:
            return
        self.busy = True
        self.status.config(text="Working…")
        self.drop_msg.config(text="Downloading subtitles…")

        def work() -> None:
            try:
                ok, fail, messages = process_paths(paths, self.lang_code)
                text = "\n".join(messages[-8:])
                if fail:
                    self.after(0, lambda: messagebox.showwarning("SubDrop", text or "Some downloads failed."))
                else:
                    self.after(0, lambda: messagebox.showinfo("SubDrop", text or f"Done — {ok} file(s)."))
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("SubDrop", str(e)))
            finally:
                self.after(0, self._idle)

        threading.Thread(target=work, daemon=True).start()

    def _idle(self) -> None:
        self.busy = False
        self.drop_msg.config(text="Drag and drop video files here\n(or use the button below)")
        self.status.config(text=f"Language: {self.lang_name} ({self.lang_code})")


def main() -> None:
    try:
        from tkinterdnd2 import TkinterDnD  # type: ignore

        class DndSubDrop(TkinterDnD.Tk, SubDropApp):
            def __init__(self) -> None:
                TkinterDnD.Tk.__init__(self)
                SubDropApp.__init__(self)

        DndSubDrop().mainloop()
    except ImportError:
        SubDropApp().mainloop()


if __name__ == "__main__":
    main()
