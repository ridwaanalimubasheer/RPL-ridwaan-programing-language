@echo off
title RPL One-File Installer and EXE Builder
setlocal

set "SELF=%~f0"
set "RPL_DIR=%USERPROFILE%\RPL"

echo ==================================================
echo   Installing RPL Studio into: %RPL_DIR%
echo ==================================================

if not exist "%RPL_DIR%" mkdir "%RPL_DIR%"
cd /d "%RPL_DIR%"

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH!
    echo Install Python from https://www.python.org/ and check "Add Python to PATH".
    pause
    exit /b 1
)

:: 1. Extract rpl_studio.py from this file
powershell -NoProfile -Command "$s = '# ===BEGIN_' + 'RPL_PY==='; $e = '# ===END_' + 'RPL_PY==='; $c = Get-Content -LiteralPath $env:SELF -Raw; $m = [regex]::Match($c, '(?s)' + $s + '(.*?)' + $e); Set-Content -Path '%RPL_DIR%\rpl_studio.py' -Value $m.Groups[1].Value.Trim() -Encoding UTF8"

:: 2. Create library.txt, main.rpl, README.txt
python "%RPL_DIR%\rpl_studio.py" --init

:: 3. Install PyInstaller & build rpl.exe
echo Building rpl.exe (please wait)...
python -m pip install --upgrade pyinstaller
python -m PyInstaller --noconfirm --onefile --windowed --name rpl --distpath "%RPL_DIR%" --workpath "%RPL_DIR%\build" --specpath "%RPL_DIR%\build" "%RPL_DIR%\rpl_studio.py"
if errorlevel 1 (
    echo [ERROR] Failed to build rpl.exe!
    pause
    exit /b 1
)

if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

:: 4. Add RPL folder to User PATH (works anywhere like System32, safely!)
powershell -NoProfile -Command "$dir = $env:RPL_DIR; $p = [Environment]::GetEnvironmentVariable('Path','User'); if ($p -notlike \"*$dir*\") { $newP = if ($p) { \"$p;$dir\" } else { $dir }; [Environment]::SetEnvironmentVariable('Path', $newP, 'User') }"

:: 5. Build RPL_Release.zip for Google Drive / Coders
powershell -NoProfile -Command "Compress-Archive -Path '%RPL_DIR%\rpl.exe','%RPL_DIR%\library.txt','%RPL_DIR%\main.rpl','%RPL_DIR%\README.txt' -DestinationPath '%RPL_DIR%\RPL_Release.zip' -Force"

echo.
echo ==================================================
echo   SUCCESS!
echo   EXE:  %RPL_DIR%\rpl.exe
echo   TXT:  %RPL_DIR%\library.txt
echo   ZIP:  %RPL_DIR%\RPL_Release.zip
echo   (You can now type "rpl" in Win+R or new CMD!)
echo ==================================================

explorer "%RPL_DIR%"
pause
exit /b 0

# ===BEGIN_RPL_PY===
import os
import sys
import time
import threading
import tkinter as tk
from tkinter import filedialog, messagebox

try:
    import winsound
except ImportError:
    winsound = None

if getattr(sys, "frozen", False):
    APP_DIR = os.path.dirname(sys.executable)
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))

LIB_PATH = os.path.join(APP_DIR, "library.txt")
CODE_PATH = os.path.join(APP_DIR, "main.rpl")
README_PATH = os.path.join(APP_DIR, "README.txt")

DEFAULT_LIB = """// RPL Daily Library (Multi-word + 8-bit ASCII binary)
open window:01101111 01110000 01100101 01101110 00100000 01110111 01101001 01101110 01100100 01101111 01110111
hello:01101000 01100101 01101100 01101100 01101111
hi:1100
go:0001
beep:1111
stop:0000
"""

DEFAULT_CODE = """// Welcome to RPL (Ridwaan Programming Language)
open window
hello
hi

go "Hello Laptop from Ridwaan!"
beep
stop
"""

DEFAULT_README = """RPL (Ridwaan Programming Language)
==================================
1. Double-click rpl.exe to start.
2. Edit library.txt every day to add new word:binary commands.
3. Write RPL code in main.rpl using words from library.txt and 'go' instead of 'print'.
"""


def ensure_files():
    if not os.path.exists(LIB_PATH):
        with open(LIB_PATH, "w", encoding="utf-8") as f:
            f.write(DEFAULT_LIB)
    if not os.path.exists(CODE_PATH):
        with open(CODE_PATH, "w", encoding="utf-8") as f:
            f.write(DEFAULT_CODE)
    if not os.path.exists(README_PATH):
        with open(README_PATH, "w", encoding="utf-8") as f:
            f.write(DEFAULT_README)


def encode_binary(text):
    return " ".join(format(ord(ch), "08b") for ch in text)


def decode_binary(binary_str):
    parts = binary_str.strip().split()
    if parts and all(len(p) == 8 and set(p) <= {"0", "1"} for p in parts):
        try:
            return "".join(chr(int(p, 2)) for p in parts)
        except ValueError:
            return None
    return None


class RPLStudioApp:
    def __init__(self, root):
        self.root = root
        self.root.title("RPL Studio — Ridwaan Programming Language")
        self.root.geometry("1220x740")
        self.root.configure(bg="#090d1a")
        self.running = False

        ensure_files()
        self._build_ui()
        self.load_files()

    def _build_ui(self):
        top = tk.Frame(self.root, bg="#11182d", pady=10, padx=16)
        top.pack(fill="x")

        title_frame = tk.Frame(top, bg="#11182d")
        title_frame.pack(side="left")
        tk.Label(
            title_frame, text="RPL STUDIO", fg="#38bdf8", bg="#11182d",
            font=("Segoe UI", 16, "bold")
        ).pack(anchor="w")
        tk.Label(
            title_frame, text="Ridwaan Programming Language • Multi-word & 8-Bit Binary → Laptop Actions",
            fg="#8f9ec9", bg="#11182d", font=("Segoe UI", 9)
        ).pack(anchor="w")

        btn_frame = tk.Frame(top, bg="#11182d")
        btn_frame.pack(side="right")

        self._btn(btn_frame, "↻ Reload .txt", self.reload_library_from_disk, "#1e294d", "#e8eefc").pack(side="left", padx=4)
        self._btn(btn_frame, "📂 Load .txt", self.pick_library_file, "#1e294d", "#e8eefc").pack(side="left", padx=4)
        self._btn(btn_frame, "💾 Save All", self.save_files, "#1e294d", "#e8eefc").pack(side="left", padx=4)
        self._btn(btn_frame, "■ Stop", self.stop_rpl, "#3b1724", "#fb7185").pack(side="left", padx=4)
        self._btn(btn_frame, "▶ Run RPL", self.start_rpl, "#10b981", "#041f13").pack(side="left", padx=4)

        main = tk.Frame(self.root, bg="#090d1a", padx=14, pady=14)
        main.pack(fill="both", expand=True)
        main.columnconfigure(0, weight=1)
        main.columnconfigure(1, weight=1)
        main.columnconfigure(2, weight=1)
        main.rowconfigure(0, weight=1)

        c1 = self._card(main, "library.txt (Daily Word : Binary)")
        c1.grid(row=0, column=0, sticky="nsew", padx=(0, 8))
        self.lib_text = self._editor(c1, fg="#fbbf24")

        gen_bar = tk.Frame(c1, bg="#11182d", padx=8, pady=6)
        gen_bar.pack(fill="x")
        self.new_cmd_entry = tk.Entry(gen_bar, bg="#080c18", fg="#e8eefc", insertbackground="#38bdf8", font=("Consolas", 10), relief="flat")
        self.new_cmd_entry.insert(0, "open window")
        self.new_cmd_entry.pack(side="left", fill="x", expand=True, padx=(0, 6), ipady=4)
        self._btn(gen_bar, "+ Add 8-bit", self.add_binary_command, "#2563eb", "#ffffff").pack(side="right")

        self.lib_status = tk.Label(c1, text="0 commands loaded", bg="#11182d", fg="#8f9ec9", anchor="w", padx=10, pady=4, font=("Segoe UI", 9))
        self.lib_status.pack(fill="x")

        c2 = self._card(main, "main.rpl (Your RPL Code)")
        c2.grid(row=0, column=1, sticky="nsew", padx=4)
        self.code_text = self._editor(c2, fg="#e2e8f0")
        tk.Label(c2, text='Try: open window   |   hello   |   go "text"', bg="#11182d", fg="#8f9ec9", anchor="w", padx=10, pady=6, font=("Segoe UI", 9)).pack(fill="x")

        c3 = tk.Frame(main, bg="#090d1a")
        c3.grid(row=0, column=2, sticky="nsew", padx=(8, 0))
        c3.rowconfigure(0, weight=1)
        c3.rowconfigure(1, weight=1)
        c3.columnconfigure(0, weight=1)

        top_r = self._card(c3, "Sent to Laptop (8-Bit Register & Binary)")
        top_r.grid(row=0, column=0, sticky="nsew", pady=(0, 8))

        led_bar = tk.Frame(top_r, bg="#070b15", padx=10, pady=8)
        led_bar.pack(fill="x")
        tk.Label(led_bar, text="8-Bit:", bg="#070b15", fg="#8f9ec9", font=("Segoe UI", 9)).pack(side="left", padx=(0, 6))
        self.leds = []
        for _ in range(8):
            lbl = tk.Label(led_bar, text="0", width=2, bg="#141d38", fg="#4f6299", font=("Consolas", 11, "bold"), relief="flat", pady=3)
            lbl.pack(side="left", padx=2)
            self.leds.append(lbl)

        self.laptop_log = self._readonly_log(top_r, fg="#34d399")

        bot_r = self._card(c3, "Screen Output (go)")
        bot_r.grid(row=1, column=0, sticky="nsew", pady=(4, 0))
        self.screen_log = self._readonly_log(bot_r, fg="#e2e8f0")

    def _btn(self, parent, text, cmd, bg, fg):
        return tk.Button(
            parent, text=text, command=cmd, bg=bg, fg=fg,
            font=("Segoe UI", 9, "bold"), relief="flat", padx=10, pady=5, cursor="hand2"
        )

    def _card(self, parent, title):
        frame = tk.Frame(parent, bg="#11182d", highlightbackground="#273663", highlightthickness=1)
        tk.Label(
            frame, text=title, bg="#17203d", fg="#e8eefc",
            font=("Segoe UI", 10, "bold"), anchor="w", padx=12, pady=8
        ).pack(fill="x")
        return frame

    def _editor(self, parent, fg):
        txt = tk.Text(
            parent, bg="#080c18", fg=fg, insertbackground="#38bdf8",
            font=("Consolas", 10), relief="flat", padx=10, pady=10, undo=True, wrap="word"
        )
        txt.pack(fill="both", expand=True)
        return txt

    def _readonly_log(self, parent, fg):
        txt = tk.Text(
            parent, bg="#060912", fg=fg, font=("Consolas", 10),
            relief="flat", padx=10, pady=10, state="disabled", wrap="word"
        )
        txt.pack(fill="both", expand=True)
        return txt

    def add_binary_command(self):
        cmd = self.new_cmd_entry.get().strip()
        if not cmd:
            return
        line = f"{cmd}:{encode_binary(cmd)}\n"
        content = self.lib_text.get("1.0", "end-1c")
        if content and not content.endswith("\n"):
            self.lib_text.insert("end", "\n")
        self.lib_text.insert("end", line)
        self.parse_library()

    def load_files(self):
        with open(LIB_PATH, "r", encoding="utf-8") as f:
            self.lib_text.delete("1.0", "end")
            self.lib_text.insert("1.0", f.read())
        with open(CODE_PATH, "r", encoding="utf-8") as f:
            self.code_text.delete("1.0", "end")
            self.code_text.insert("1.0", f.read())
        self.parse_library()

    def reload_library_from_disk(self):
        if os.path.exists(LIB_PATH):
            with open(LIB_PATH, "r", encoding="utf-8") as f:
                self.lib_text.delete("1.0", "end")
                self.lib_text.insert("1.0", f.read())
            d = self.parse_library()
            messagebox.showinfo("Reloaded", f"Loaded {len(d)} commands from library.txt!")

    def pick_library_file(self):
        path = filedialog.askopenfilename(title="Open .txt Library", filetypes=[("Text Files", "*.txt")])
        if not path:
            return
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        self.lib_text.delete("1.0", "end")
        self.lib_text.insert("1.0", content)
        self.parse_library()

    def save_files(self):
        self.save_files_silent()
        self.parse_library()
        messagebox.showinfo("Saved", "Saved library.txt and main.rpl!")

    def save_files_silent(self):
        with open(LIB_PATH, "w", encoding="utf-8") as f:
            f.write(self.lib_text.get("1.0", "end-1c"))
        with open(CODE_PATH, "w", encoding="utf-8") as f:
            f.write(self.code_text.get("1.0", "end-1c"))

    def parse_library(self):
        dictionary = {}
        for raw in self.lib_text.get("1.0", "end-1c").splitlines():
            line = raw.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue
            if ":" in line:
                word, code = line.split(":", 1)
                word, code = word.strip(), code.strip()
                if word:
                    dictionary[word] = code
        self.lib_status.config(text=f"{len(dictionary)} commands loaded from library.txt")
        return dictionary

    def _append_log(self, widget, msg):
        widget.config(state="normal")
        widget.insert("end", msg + "\n")
        widget.see("end")
        widget.config(state="disabled")

    def _clear_logs(self):
        for w in (self.laptop_log, self.screen_log):
            w.config(state="normal")
            w.delete("1.0", "end")
            w.config(state="disabled")

    def _update_leds(self, binary_str):
        chunks = [p for p in binary_str.strip().split() if set(p) <= {"0", "1"}]
        last_byte = chunks[-1] if chunks else "00000000"
        bits = list(last_byte[-8:].rjust(8, "0"))
        for lbl, b in zip(self.leds, bits):
            if b == "1":
                lbl.config(text="1", bg="#123d31", fg="#34d399")
            else:
                lbl.config(text="0", bg="#141d38", fg="#4f6299")

    def _open_rpl_window(self, title_text, binary_used):
        win = tk.Toplevel(self.root)
        win.title(title_text)
        win.geometry("420x220")
        win.configure(bg="#11182d")
        tk.Label(win, text="🪟 " + title_text, bg="#11182d", fg="#38bdf8", font=("Segoe UI", 16, "bold")).pack(pady=(28, 10))
        tk.Label(win, text="Opened by RPL 8-bit binary command!", bg="#11182d", fg="#e8eefc", font=("Segoe UI", 11)).pack(pady=4)
        tk.Label(win, text=binary_used, bg="#080c18", fg="#34d399", font=("Consolas", 8), wraplength=380, padx=10, pady=8).pack(pady=14, padx=16, fill="x")

    def stop_rpl(self):
        self.running = False

    def start_rpl(self):
        self.save_files_silent()
        self._clear_logs()
        self.running = True
        dictionary = self.parse_library()
        lines = self.code_text.get("1.0", "end-1c").splitlines()
        threading.Thread(target=self._run_worker, args=(dictionary, lines), daemon=True).start()

    def _send_laptop(self, word, binary, extra_arg=None):
        decoded = decode_binary(binary)
        if decoded:
            msg = f"{word} ──▶ {binary}  (decoded: '{decoded}')"
        else:
            msg = f"{word} ──▶ {binary}"

        self.root.after(0, self._append_log, self.laptop_log, msg)
        self.root.after(0, self._update_leds, binary)

        action = (decoded or word).lower()
        if action == "open window":
            self.root.after(0, self._open_rpl_window, extra_arg or "RPL Window", binary)
        elif action == "beep" and winsound:
            try:
                winsound.Beep(700, 160)
            except Exception:
                pass

    def _run_worker(self, dictionary, lines):
        loop_stack = []
        i = 0
        steps = 0
        sorted_keys = sorted(dictionary.keys(), key=len, reverse=True)

        while i < len(lines) and self.running:
            steps += 1
            if steps > 2000:
                self.root.after(0, self._append_log, self.screen_log, "ERROR: Too many steps")
                break

            line_num = i + 1
            line = lines[i].split("//")[0].strip()
            i += 1
            if not line:
                continue

            if line.startswith("repeat "):
                try:
                    count = int(line[7:].strip())
    