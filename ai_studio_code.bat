@echo off
title RPL v3.0 Installer, Updater and EXE Builder
setlocal

set "SELF=%~f0"
set "RPL_DIR=%USERPROFILE%\RPL"

echo ==================================================
echo   Installing RPL Studio v3.0 into: %RPL_DIR%
echo ==================================================

:: Close rpl.exe if running
taskkill /f /im rpl.exe >nul 2>&1
timeout /t 1 /nobreak >nul

if not exist "%RPL_DIR%" mkdir "%RPL_DIR%"
cd /d "%RPL_DIR%"

:: Backup existing library.txt before upgrading
if exist "%RPL_DIR%\library.txt" copy /y "%RPL_DIR%\library.txt" "%RPL_DIR%\library.txt.bak" >nul

:: Delete old version files
if exist "%RPL_DIR%\rpl.exe" del /f /q "%RPL_DIR%\rpl.exe"
if exist "%RPL_DIR%\rpl_studio.py" del /f /q "%RPL_DIR%\rpl_studio.py"
if exist "%RPL_DIR%\RPL_Release.zip" del /f /q "%RPL_DIR%\RPL_Release.zip"
if exist "%RPL_DIR%\main.rpl" del /f /q "%RPL_DIR%\main.rpl"
if exist "%RPL_DIR%\README.txt" del /f /q "%RPL_DIR%\README.txt"
if exist "%RPL_DIR%\library.txt" del /f /q "%RPL_DIR%\library.txt"
if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH!
    pause
    exit /b 1
)

:: 1. Extract v3.0 rpl_studio.py
powershell -NoProfile -Command "$s = '# ===BEGIN_' + 'RPL_PY==='; $e = '# ===END_' + 'RPL_PY==='; $c = Get-Content -LiteralPath $env:SELF -Raw; $m = [regex]::Match($c, '(?s)' + $s + '(.*?)' + $e); Set-Content -Path '%RPL_DIR%\rpl_studio.py' -Value $m.Groups[1].Value.Trim() -Encoding UTF8"

:: 2. Initialize files
python "%RPL_DIR%\rpl_studio.py" --init

:: 3. Build rpl.exe
echo Building rpl.exe v3.0...
python -m pip install --upgrade pyinstaller
python -m PyInstaller --noconfirm --onefile --windowed --name rpl --distpath "%RPL_DIR%" --workpath "%RPL_DIR%\build" --specpath "%RPL_DIR%\build" "%RPL_DIR%\rpl_studio.py"
if errorlevel 1 (
    echo [ERROR] Failed to build rpl.exe!
    pause
    exit /b 1
)

if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

:: 4. Add RPL folder to User PATH
powershell -NoProfile -Command "$dir = $env:RPL_DIR; $p = [Environment]::GetEnvironmentVariable('Path','User'); if ($p -notlike \"*$dir*\") { $newP = if ($p) { \"$p;$dir\" } else { $dir }; [Environment]::SetEnvironmentVariable('Path', $newP, 'User') }"

:: 5. Build RPL_Release.zip safely (retries automatically if Antivirus scans rpl.exe)
timeout /t 3 /nobreak >nul
powershell -NoProfile -Command "for ($i=1; $i -le 10; $i++) { try { Compress-Archive -Path '%RPL_DIR%\rpl.exe','%RPL_DIR%\library.txt','%RPL_DIR%\hello.rpl','%RPL_DIR%\update_url.txt','%RPL_DIR%\README.txt' -DestinationPath '%RPL_DIR%\RPL_Release.zip' -Force -ErrorAction Stop; break } catch { Write-Host 'Waiting for Antivirus scan...'; Start-Sleep -Seconds 2 } }"

echo.
echo ==================================================
echo   RPL v3.0 READY!
echo   EXE:  %RPL_DIR%\rpl.exe
echo   ZIP:  %RPL_DIR%\RPL_Release.zip
echo ==================================================

start "" "%RPL_DIR%\rpl.exe"
explorer "%RPL_DIR%"
pause
exit /b 0

# ===BEGIN_RPL_PY===
import os
import re
import sys
import time
import shutil
import ctypes
import random
import traceback
import threading
import urllib.request
import math as py_math
import tkinter as tk
from tkinter import filedialog, messagebox

try:
    import winsound
except ImportError:
    winsound = None

VERSION = "3.0"

if getattr(sys, "frozen", False):
    APP_DIR = os.path.dirname(sys.executable)
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))

LIB_PATH = os.path.join(APP_DIR, "library.txt")
LIB_BACKUP_PATH = os.path.join(APP_DIR, "library.txt.bak")
DEFAULT_CODE_PATH = os.path.join(APP_DIR, "hello.rpl")
URL_CONFIG_PATH = os.path.join(APP_DIR, "update_url.txt")
README_PATH = os.path.join(APP_DIR, "README.txt")
CRASH_LOG_PATH = os.path.join(APP_DIR, "rpl_error.log")
DOWNLOADS_LIB_PATH = os.path.join(os.path.expanduser("~"), "Downloads", "library.txt")

DEFAULT_LIB = """// RPL Real 8-Bit ASCII Binary Library
// Format: command:binary | description for devs
open window:01101111 01110000 01100101 01101110 00100000 01110111 01101001 01101110 01100100 01101111 01110111 | Opens a new RPL window
hello:01101000 01100101 01101100 01101100 01101111 | Sends hello in 8-bit ASCII binary
hi:01101000 01101001 | Sends hi in 8-bit ASCII binary
go:01100111 01101111 | Prints text to screen (like Python print)
beep:01100010 01100101 01100101 01110000 | Plays a beep sound on the laptop
stop:01110011 01110100 01101111 01110000 | Sends stop signal
"""

DEFAULT_CODE = """// hello.rpl - Write RPL just like Python!
use math
use text

name = "Ridwaan"
score = 10

go "Hello " + name + "!"
go("Uppercase: " + text.upper(name))

if score >= 10:
    go "Level Up!"
    hello
else:
    go "Keep coding!"

for i in range(3):
    lucky = math.rand(1, 50)
    go "Lucky number " + str(i + 1) + ": " + str(lucky)

def greet(who):
    go "Welcome to RPL, " + who + "!"

greet(name)
open window "Ridwaan App"
beep
"""

DEFAULT_URL_CFG = """# Optional: Paste your Google Drive share link or raw .txt URL on the line below
# Example: https://drive.google.com/file/d/YOUR_FILE_ID/view?usp=sharing
"""

DEFAULT_README = """RPL v3.0 (Ridwaan Programming Language)
=======================================
1. Double-click rpl.exe to launch RPL Studio.
2. Write Python-style code in .rpl files (example: hello.rpl).
3. Updating library.txt:
   - Download a new library.txt to your Downloads folder and RPL will ask to update automatically!
   - OR paste your Google Drive link in update_url.txt and click "Check Updates".
4. Click "Library Base" inside RPL Studio to see all commands & libraries.
"""


def ensure_files():
    defaults = [
        (LIB_PATH, DEFAULT_LIB),
        (DEFAULT_CODE_PATH, DEFAULT_CODE),
        (URL_CONFIG_PATH, DEFAULT_URL_CFG),
        (README_PATH, DEFAULT_README),
    ]
    for path, content in defaults:
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)


def validate_library_text(content):
    head = content[:500].lower()
    if "<html" in head or "<!doctype" in head:
        return False, "Downloaded file is an HTML webpage, not a plain .txt file (check Google Drive sharing!)."
    count = 0
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        if ":" in line:
            word, rest = line.split(":", 1)
            if word.strip() and rest.strip():
                count += 1
    if count == 0:
        return False, "No valid 'command:binary' lines found in the file."
    return True, count


def safe_write_library(new_content):
    ok, info = validate_library_text(new_content)
    if not ok:
        raise ValueError(info)
    if os.path.exists(LIB_PATH):
        shutil.copy2(LIB_PATH, LIB_BACKUP_PATH)
    tmp_path = LIB_PATH + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    os.replace(tmp_path, LIB_PATH)
    return info


def normalize_download_url(url):
    url = url.strip()
    # Convert normal Google Drive share links into direct download links
    m = re.search(r"drive\.google\.com/file/d/([a-zA-Z0-9_-]+)", url)
    if m:
        return f"https://drive.google.com/uc?export=download&id={m.group(1)}"
    m2 = re.search(r"drive\.google\.com/open\?id=([a-zA-Z0-9_-]+)", url)
    if m2:
        return f"https://drive.google.com/uc?export=download&id={m2.group(1)}"
    return url


def read_configured_url():
    if not os.path.exists(URL_CONFIG_PATH):
        return ""
    with open(URL_CONFIG_PATH, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if line and not line.startswith("#") and line.startswith(("http://", "https://")):
                return line
    return ""


def save_configured_url(url):
    with open(URL_CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write("# Paste your Google Drive share link or raw .txt URL below:\n")
        if url.strip():
            f.write(url.strip() + "\n")


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


def strip_comment(line):
    in_quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if ch in ('"', "'") and (i == 0 or line[i - 1] != "\\"):
            if in_quote == ch:
                in_quote = None
            elif in_quote is None:
                in_quote = ch
        elif in_quote is None:
            if ch == "#":
                return line[:i].rstrip()
            if ch == "/" and i + 1 < len(line) and line[i + 1] == "/":
                return line[:i].rstrip()
        i += 1
    return line.rstrip()


class MathLib:
    pi = round(py_math.pi, 5)
    def rand(self, a=1, b=10): return random.randint(int(a), int(b))
    def sqrt(self, x): return py_math.sqrt(x)
    def round(self, x): return round(x)
    def abs(self, x): return abs(x)


class TextLib:
    def upper(self, s): return str(s).upper()
    def lower(self, s): return str(s).lower()
    def reverse(self, s): return str(s)[::-1]
    def len(self, s): return len(str(s))


class TimeLib:
    def now(self): return time.strftime("%H:%M:%S")
    def year(self): return int(time.strftime("%Y"))
    def wait(self, ms=500): time.sleep(min(float(ms) / 1000.0, 5.0))


class UILib:
    def __init__(self, app):
        self.app = app
    def window(self, title="RPL Window", message="Opened from RPL ui.window()"):
        self.app.root.after(0, self.app._open_rpl_window, str(title), str(message))
    def alert(self, title="RPL Alert", message="Hello!"):
        self.app.root.after(0, messagebox.showinfo, str(title), str(message))


class RPLStudioApp:
    def __init__(self, root):
        self.root = root
        self.root.title(f"RPL Studio v{VERSION} - Ridwaan Programming Language")
        self.root.geometry("1260x760")
        self.root.configure(bg="#090d1a")
        self.running = False
        self.current_rpl_path = DEFAULT_CODE_PATH
        self.pure_binary_var = tk.BooleanVar(value=True)

        ensure_files()
        self._build_ui()
        self.load_files()

        self.root.bind("<Control-s>", lambda e: self.save_files())
        self.root.after(400, self.startup_update_check)

    def _build_ui(self):
        top = tk.Frame(self.root, bg="#11182d", pady=10, padx=16)
        top.pack(fill="x")

        title_frame = tk.Frame(top, bg="#11182d")
        title_frame.pack(side="left")
        tk.Label(
            title_frame, text=f"RPL STUDIO v{VERSION}", fg="#38bdf8", bg="#11182d",
            font=("Segoe UI", 16, "bold")
        ).pack(anchor="w")
        tk.Label(
            title_frame, text="Reliable Python-style .rpl IDE | Auto-Updating library.txt & Real 8-Bit Binary",
            fg="#8f9ec9", bg="#11182d", font=("Segoe UI", 9)
        ).pack(anchor="w")

        btn_frame = tk.Frame(top, bg="#11182d")
        btn_frame.pack(side="right")

        self._btn(btn_frame, "Library Base", self.open_library_base, "#2563eb", "#ffffff").pack(side="left", padx=3)
        self._btn(btn_frame, "Check Updates", self.open_update_dialog, "#0f766e", "#ffffff").pack(side="left", padx=3)
        self._btn(btn_frame, "Reload .txt", self.reload_library_from_disk, "#1e294d", "#e8eefc").pack(side="left", padx=3)
        self._btn(btn_frame, "Open .rpl", self.open_rpl_file, "#1e294d", "#e8eefc").pack(side="left", padx=3)
        self._btn(btn_frame, "Save (Ctrl+S)", self.save_files, "#1e294d", "#e8eefc").pack(side="left", padx=3)
        self._btn(btn_frame, "Stop", self.stop_rpl, "#3b1724", "#fb7185").pack(side="left", padx=3)
        self._btn(btn_frame, "Run RPL", self.start_rpl, "#10b981", "#041f13").pack(side="left", padx=3)

        main = tk.Frame(self.root, bg="#090d1a", padx=14, pady=14)
        main.pack(fill="both", expand=True)
        main.columnconfigure(0, weight=1)
        main.columnconfigure(1, weight=1)
        main.columnconfigure(2, weight=1)
        main.rowconfigure(0, weight=1)

        c1 = self._card(main, "library.txt (Real 8-Bit Binary Commands)")
        c1.grid(row=0, column=0, sticky="nsew", padx=(0, 8))
        self.lib_text = self._editor(c1, fg="#fbbf24")
        self.lib_status = tk.Label(c1, text="0 commands loaded", bg="#11182d", fg="#8f9ec9", anchor="w", padx=10, pady=6, font=("Segoe UI", 9))
        self.lib_status.pack(fill="x")

        c2 = tk.Frame(main, bg="#11182d", highlightbackground="#273663", highlightthickness=1)
        c2.grid(row=0, column=1, sticky="nsew", padx=4)
        self.code_header = tk.Label(
            c2, text="hello.rpl (Python-style RPL Code)", bg="#17203d", fg="#e8eefc",
            font=("Segoe UI", 10, "bold"), anchor="w", padx=12, pady=8
        )
        self.code_header.pack(fill="x")
        self.code_text = self._editor(c2, fg="#e2e8f0")
        tk.Label(c2, text='Python style: name = "Ridwaan"  |  if/else  |  for  |  def  |  go', bg="#11182d", fg="#8f9ec9", anchor="w", padx=10, pady=6, font=("Segoe UI", 9)).pack(fill="x")

        c3 = tk.Frame(main, bg="#090d1a")
        c3.grid(row=0, column=2, sticky="nsew", padx=(8, 0))
        c3.rowconfigure(0, weight=1)
        c3.rowconfigure(1, weight=1)
        c3.columnconfigure(0, weight=1)

        top_r = tk.Frame(c3, bg="#11182d", highlightbackground="#273663", highlightthickness=1)
        top_r.grid(row=0, column=0, sticky="nsew", pady=(0, 8))
        top_r_head = tk.Frame(top_r, bg="#17203d")
        top_r_head.pack(fill="x")
        tk.Label(
            top_r_head, text="Sent to Laptop (Binary Signal)", bg="#17203d", fg="#e8eefc",
            font=("Segoe UI", 10, "bold"), anchor="w", padx=12, pady=8
        ).pack(side="left")
        tk.Checkbutton(
            top_r_head, text="Pure Binary Only", variable=self.pure_binary_var,
            bg="#17203d", fg="#34d399", selectcolor="#090d1a",
            activebackground="#17203d", activeforeground="#34d399",
            font=("Segoe UI", 8, "bold")
        ).pack(side="right", padx=10)

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
            font=("Segoe UI", 9, "bold"), relief="flat", padx=9, pady=5, cursor="hand2"
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

    # --- Auto Update Logic (Downloads folder + Google Drive / URL) ---
    def startup_update_check(self):
        # 1. Check if user downloaded a newer library.txt normally into Downloads
        if os.path.exists(DOWNLOADS_LIB_PATH) and os.path.exists(LIB_PATH):
            try:
                dl_mtime = os.path.getmtime(DOWNLOADS_LIB_PATH)
                cur_mtime = os.path.getmtime(LIB_PATH)
                if dl_mtime > cur_mtime + 2:
                    with open(DOWNLOADS_LIB_PATH, "r", encoding="utf-8") as f:
                        new_content = f.read()
                    ok, count = validate_library_text(new_content)
                    if ok:
                        if messagebox.askyesno(
                            "New library.txt Found!",
                            f"A newer library.txt ({count} commands) was found in your Downloads folder.\n\nUpdate RPL's library.txt now?"
                        ):
                            safe_write_library(new_content)
                            self.reload_library_from_disk(silent=True)
                            self._append_log(self.screen_log, f"[Updater] Updated library.txt from Downloads ({count} commands).")
                            return
            except Exception:
                pass

        # 2. Check configured online URL silently in background
        url = read_configured_url()
        if url:
            threading.Thread(target=self._download_url_worker, args=(url, True), daemon=True).start()

    def open_update_dialog(self):
        win = tk.Toplevel(self.root)
        win.title("Update library.txt")
        win.geometry("580x320")
        win.configure(bg="#11182d")

        tk.Label(win, text="Update library.txt", bg="#11182d", fg="#38bdf8", font=("Segoe UI", 14, "bold")).pack(anchor="w", padx=18, pady=(16, 4))
        tk.Label(
            win,
            text="Option 1: Import a library.txt you downloaded normally to your Downloads folder.\nOption 2: Paste a Google Drive share link (set to 'Anyone with the link') or raw .txt URL.",
            bg="#11182d", fg="#cbd5e1", justify="left", font=("Segoe UI", 9)
        ).pack(anchor="w", padx=18, pady=(0, 12))

        url_entry = tk.Entry(win, bg="#080c18", fg="#e8eefc", insertbackground="#38bdf8", font=("Consolas", 10), relief="flat")
        url_entry.insert(0, read_configured_url())
        url_entry.pack(fill="x", padx=18, ipady=7)

        status_lbl = tk.Label(win, text="", bg="#11182d", fg="#34d399", font=("Segoe UI", 9))
        status_lbl.pack(anchor="w", padx=18, pady=8)

        btn_row = tk.Frame(win, bg="#11182d")
        btn_row.pack(fill="x", padx=18, pady=10)

        def import_downloads():
            if not os.path.exists(DOWNLOADS_LIB_PATH):
                path = filedialog.askopenfilename(title="Select downloaded library.txt", initialdir=os.path.join(os.path.expanduser("~"), "Downloads"), filetypes=[("Text Files", "*.txt")])
                if not path:
                    return
            else:
                path = DOWNLOADS_LIB_PATH
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                count = safe_write_library(content)
                self.reload_library_from_disk(silent=True)
                status_lbl.config(text=f"Updated from file! ({count} commands loaded)", fg="#34d399")
            except Exception as e:
                status_lbl.config(text=f"Error: {e}", fg="#fb7185")

        def download_from_url():
            raw_url = url_entry.get().strip()
            if not raw_url:
                status_lbl.config(text="Please paste a Google Drive or .txt URL first.", fg="#fbbf24")
                return
            save_configured_url(raw_url)
            status_lbl.config(text="Downloading...", fg="#38bdf8")
            threading.Thread(target=self._download_url_worker, args=(raw_url, False, status_lbl), daemon=True).start()

        self._btn(btn_row, "Import from Downloads", import_downloads, "#1e294d", "#e8eefc").pack(side="left", padx=(0, 8))
        self._btn(btn_row, "Download & Update Now", download_from_url, "#10b981", "#041f13").pack(side="left")

    def _download_url_worker(self, raw_url, silent, status_lbl=None):
        try:
            direct_url = normalize_download_url(raw_url)
            req = urllib.request.Request(direct_url, headers={"User-Agent": "RPL-Studio/3.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                content = resp.read().decode("utf-8", errors="replace")

            cur = ""
            if os.path.exists(LIB_PATH):
                with open(LIB_PATH, "r", encoding="utf-8") as f:
                    cur = f.read()

            if content.strip() == cur.strip():
                if not silent and status_lbl:
                    self.root.after(0, lambda: status_lbl.config(text="Already up to date!", fg="#34d399"))
                return

            count = safe_write_library(content)
            self.root.after(0, lambda: self.reload_library_from_disk(silent=True))
            self.root.after(0, self._append_log, self.screen_log, f"[Updater] library.txt auto-updated ({count} commands).")
            if not silent and status_lbl:
                self.root.after(0, lambda: status_lbl.config(text=f"Success! Updated ({count} commands).", fg="#34d399"))
        except Exception as e:
            if not silent and status_lbl:
                self.root.after(0, lambda err=str(e): status_lbl.config(text=f"Update failed: {err}", fg="#fb7185"))

    def open_library_base(self):
        _, meta = self.parse_library()
        win = tk.Toplevel(self.root)
        win.title("RPL Library Base - Developer Guide")
        win.geometry("780x620")
        win.configure(bg="#090d1a")

        tk.Label(
            win, text="RPL LIBRARY BASE (Developer Reference)",
            bg="#11182d", fg="#38bdf8", font=("Segoe UI", 14, "bold"), anchor="w", padx=16, pady=12
        ).pack(fill="x")

        box = tk.Text(win, bg="#080c18", fg="#e2e8f0", font=("Consolas", 10), relief="flat", padx=16, pady=14, wrap="word")
        box.pack(fill="both", expand=True, padx=12, pady=12)

        lines = []
        lines.append("=== 1. DAILY COMMANDS FROM library.txt ===")
        lines.append("(Use these directly in your .rpl file!)\n")
        for cmd, info in meta.items():
            desc = info["desc"] or "Custom binary command"
            lines.append(f"  {cmd:<14} -> {desc}")
            lines.append(f"                    Binary: {info['code']}")
        lines.append("\n=== 2. BUILT-IN PYTHON-STYLE LIBRARIES (use <name>) ===\n")
        lines.append("  use math")
        lines.append("    math.rand(min, max)  -> Random number (e.g. math.rand(1, 50))")
        lines.append("    math.sqrt(x)         -> Square root")
        lines.append("    math.round(x)        -> Round number")
        lines.append("    math.abs(x)          -> Absolute value")
        lines.append("    math.pi              -> 3.14159\n")
        lines.append("  use text")
        lines.append("    text.upper(s)        -> UPPERCASE text")
        lines.append("    text.lower(s)        -> lowercase text")
        lines.append("    text.reverse(s)      -> Reverse text")
        lines.append("    text.len(s)          -> Length of text\n")
        lines.append("  use time")
        lines.append("    time.now()           -> Current time (HH:MM:SS)")
        lines.append("    time.year()          -> Current year")
        lines.append("    time.wait(ms)        -> Pause (e.g. time.wait(500))\n")
        lines.append("  use ui")
        lines.append('    ui.window("Title", "Msg") -> Open custom window')
        lines.append('    ui.alert("Title", "Msg")  -> Show popup message\n')
        lines.append("=== 3. HOW TO WRITE .rpl CODE (LIKE PYTHON) ===\n")
        lines.append('  name = "Ridwaan"               // Variable')
        lines.append('  go "Hello " + name             // Print (instead of print)')
        lines.append("  if score >= 10:                // Condition")
        lines.append('      go "You win!"')
        lines.append("  else:")
        lines.append('      go "Try again"')
        lines.append("  for i in range(3):             // Loop 3 times")
        lines.append("      go i")
        lines.append("  def greet(who):                // Function")
        lines.append('      go "Hi " + who')
        lines.append('  greet("Coder")')

        box.insert("1.0", "\n".join(lines))
        box.config(state="disabled")

    def load_files(self):
        with open(LIB_PATH, "r", encoding="utf-8") as f:
            self.lib_text.delete("1.0", "end")
            self.lib_text.insert("1.0", f.read())
        with open(self.current_rpl_path, "r", encoding="utf-8") as f:
            self.code_text.delete("1.0", "end")
            self.code_text.insert("1.0", f.read())
        self.code_header.config(text=f"{os.path.basename(self.current_rpl_path)} (Python-style RPL Code)")
        self.parse_library()

    def reload_library_from_disk(self, silent=False):
        if os.path.exists(LIB_PATH):
            with open(LIB_PATH, "r", encoding="utf-8") as f:
                self.lib_text.delete("1.0", "end")
                self.lib_text.insert("1.0", f.read())
            d, _ = self.parse_library()
            if not silent:
                messagebox.showinfo("Reloaded", f"Loaded {len(d)} commands from library.txt!")

    def open_rpl_file(self):
        path = filedialog.askopenfilename(title="Open .rpl File", initialdir=APP_DIR, filetypes=[("RPL Files", "*.rpl"), ("All Files", "*.*")])
        if not path:
            return
        self.current_rpl_path = path
        with open(path, "r", encoding="utf-8") as f:
            self.code_text.delete("1.0", "end")
            self.code_text.insert("1.0", f.read())
        self.code_header.config(text=f"{os.path.basename(path)} (Python-style RPL Code)")

    def save_files(self):
        try:
            self.save_files_silent()
            self.parse_library()
            messagebox.showinfo("Saved", f"Saved library.txt and {os.path.basename(self.current_rpl_path)}!")
        except Exception as e:
            messagebox.showerror("Save Error", str(e))

    def save_files_silent(self):
        lib_content = self.lib_text.get("1.0", "end-1c")
        safe_write_library(lib_content)
        with open(self.current_rpl_path, "w", encoding="utf-8") as f:
            f.write(self.code_text.get("1.0", "end-1c"))

    def parse_library(self):
        dictionary = {}
        meta = {}
        for raw in self.lib_text.get("1.0", "end-1c").splitlines():
            line = raw.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue
            if ":" in line:
                word, rest = line.split(":", 1)
                word = word.strip()
                if "|" in rest:
                    code, desc = rest.split("|", 1)
                else:
                    code, desc = rest, ""
                code, desc = code.strip(), desc.strip()
                if word:
                    dictionary[word] = code
                    meta[word] = {"code": code, "desc": desc}
        self.lib_status.config(text=f"{len(dictionary)} commands loaded from library.txt")
        return dictionary, meta

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

    def _open_rpl_window(self, title_text, body_text):
        win = tk.Toplevel(self.root)
        win.title(title_text)
        win.geometry("430x220")
        win.configure(bg="#11182d")
        tk.Label(win, text="[RPL] " + title_text, bg="#11182d", fg="#38bdf8", font=("Segoe UI", 15, "bold")).pack(pady=(26, 10))
        tk.Label(win, text=body_text, bg="#080c18", fg="#34d399", font=("Consolas", 9), wraplength=380, padx=12, pady=10).pack(pady=10, padx=16, fill="x")

    def stop_rpl(self):
        self.running = False

    def start_rpl(self):
        try:
            self.save_files_silent()
        except Exception as e:
            messagebox.showerror("library.txt Error", str(e))
            return
        self._clear_logs()
        self.running = True
        dictionary, _ = self.parse_library()
        raw_lines = self.code_text.get("1.0", "end-1c").splitlines()
        threading.Thread(target=self._run_worker, args=(dictionary, raw_lines), daemon=True).start()

    def _send_laptop(self, word, binary, extra_arg=None):
        decoded = decode_binary(binary)
        if self.pure_binary_var.get():
            msg = binary
        elif decoded:
            msg = f"{word} --> {binary}  (decoded: '{decoded}')"
        else:
            msg = f"{word} --> {binary}"

        self.root.after(0, self._append_log, self.laptop_log, msg)
        self.root.after(0, self._update_leds, binary)

        action = (decoded or word).lower()
        if action == "open window":
            self.root.after(0, self._open_rpl_window, extra_arg or "RPL Window", "Opened by 8-bit binary:\n" + binary)
        elif action == "beep" and winsound:
            try:
                winsound.Beep(700, 160)
            except Exception:
                pass

    def _parse_python_blocks(self, raw_lines):
        tokens = []
        for idx, raw in enumerate(raw_lines):
            expanded = raw.replace("\t", "    ")
            cleaned = strip_comment(expanded)
            if not cleaned.strip():
                continue
            indent = len(expanded) - len(expanded.lstrip(" "))
            tokens.append((idx + 1, indent, cleaned.strip()))

        def build_block(pos, base_indent):
            nodes = []
            while pos < len(tokens):
                line_num, indent, text = tokens[pos]
                if indent < base_indent:
                    break
                if indent > base_indent:
                    raise SyntaxError(f"Line {line_num}: Unexpected indentation")

                if text.endswith(":"):
                    header = text[:-1].strip()
                    pos += 1
                    if pos >= len(tokens) or tokens[pos][1] <= indent:
                        raise SyntaxError(f"Line {line_num}: Expected an indented block after ':'")
                    body, pos = build_block(pos, tokens[pos][1])
                    nodes.append({"type": "block", "line": line_num, "header": header, "body": body})
                else:
                    nodes.append({"type": "stmt", "line": line_num, "text": text})
                    pos += 1
            return nodes, pos

        ast, _ = build_block(0, tokens[0][1] if tokens else 0)
        return ast

    def _run_worker(self, dictionary, raw_lines):
        env = {
            "str": str, "int": int, "float": float, "len": len,
            "range": range, "round": round, "abs": abs,
            "min": min, "max": max, "bool": bool,
            "True": True, "False": False, "None": None
        }
        sorted_keys = sorted(dictionary.keys(), key=len, reverse=True)
        steps = [0]

        def safe_eval(expr, line_num):
            try:
                return eval(expr, {"__builtins__": {}}, env)
            except Exception as e:
                raise RuntimeError(f"Line {line_num}: {e}")

        def exec_nodes(nodes):
            i = 0
            while i < len(nodes) and self.running:
                steps[0] += 1
                if steps[0] > 5000:
                    raise RuntimeError("Program stopped (too many steps - possible infinite loop)")

                node = nodes[i]
                line_num = node["line"]

                if node["type"] == "block":
                    hdr = node["header"]

                    if hdr.startswith("if "):
                        matched = False
                        if safe_eval(hdr[3:].strip(), line_num):
                            exec_nodes(node["body"])
                            matched = True
                        j = i + 1
                        while j < len(nodes) and nodes[j]["type"] == "block":
                            nh = nodes[j]["header"]
                            if nh.startswith("elif "):
                                if not matched and safe_eval(nh[5:].strip(), nodes[j]["line"]):
                                    exec_nodes(nodes[j]["body"])
                                    matched = True
                                j += 1
                            elif nh == "else":
                                if not matched:
                                    exec_nodes(nodes[j]["body"])
                                    matched = True
                                j += 1
                                break
                            else:
                                break
                        i = j
                        continue

                    if hdr.startswith("elif ") or hdr == "else":
                        raise RuntimeError(f"Line {line_num}: '{hdr}' without matching 'if'")

                    m_for = re.match(r"^for\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+in\s+(.+)$", hdr)
                    if m_for:
                        var_name = m_for.group(1)
                        iterable = safe_eval(m_for.group(2).strip(), line_num)
                        for val in iterable:
                            if not self.running:
                                break
                            env[var_name] = val
                            exec_nodes(node["body"])
                        i += 1
                        continue

                    if hdr.startswith("while "):
                        cond_expr = hdr[6:].strip()
                        while self.running and safe_eval(cond_expr, line_num):
                            steps[0] += 1
                            if steps[0] > 5000:
                                raise RuntimeError("Loop stopped (too many steps)")
                            exec_nodes(node["body"])
                        i += 1
                        continue

                    m_def = re.match(r"^def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)$", hdr)
                    if m_def:
                        fn_name = m_def.group(1)
                        params = [p.strip() for p in m_def.group(2).split(",") if p.strip()]
                        body_ref = node["body"]

                        def rpl_func(*args, _params=params, _body=body_ref):
                            saved = {}
                            for idx_p, p in enumerate(_params):
                                if p in env:
                                    saved[p] = env[p]
                                env[p] = args[idx_p] if idx_p < len(args) else None
                            exec_nodes(_body)
                            for p in _params:
                                if p in saved:
                                    env[p] = saved[p]
                                else:
                                    env.pop(p, None)

                        env[fn_name] = rpl_func
                        i += 1
                        continue

                    raise RuntimeError(f"Line {line_num}: Unknown block '{hdr}:'")

                stmt = node["text"]
                i += 1

                if stmt.startswith("use ") or stmt.startswith("import "):
                    lib_name = stmt.split(None, 1)[1].strip()
                    if lib_name == "math":
                        env["math"] = MathLib()
                    elif lib_name == "text":
                        env["text"] = TextLib()
                    elif lib_name == "time":
                        env["time"] = TimeLib()
                    elif lib_name == "ui":
                        env["ui"] = UILib(self)
                    else:
                        raise RuntimeError(f"Line {line_num}: Unknown library '{lib_name}'. Check Library Base!")
                    continue

                if stmt == "go" or stmt.startswith("go ") or (stmt.startswith("go(") and stmt.endswith(")")):
                    if "go" in dictionary:
                        self._send_laptop("go", dictionary["go"])
                    if stmt == "go":
                        out_val = ""
                    elif stmt.startswith("go(") and stmt.endswith(")"):
                        inner = stmt[3:-1].strip()
                        out_val = safe_eval(inner, line_num) if inner else ""
                    else:
                        inner = stmt[3:].strip()
                        if inner in dictionary and inner not in env:
                            out_val = dictionary[inner]
                            self._send_laptop(inner, dictionary[inner])
                        else:
                            out_val = safe_eval(inner, line_num)
                    self.root.after(0, self._append_log, self.screen_log, f"> {out_val}")
                    if isinstance(out_val, str) and out_val:
                        self._send_laptop(f'"{out_val}"', encode_binary(out_val))
                    time.sleep(0.1)
                    continue

                m_assign = re.match(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*=(?!=)\s*(.+)$", stmt)
                if m_assign:
                    env[m_assign.group(1)] = safe_eval(m_assign.group(2).strip(), line_num)
                    continue

                matched_cmd = None
                extra_arg = None
                for k in sorted_keys:
                    if stmt == k:
                        matched_cmd = k
                        break
                    elif stmt.startswith(k + " "):
                        rest = stmt[len(k):].strip()
                        if (rest.startswith('"') and rest.endswith('"')) or (rest.startswith("'") and rest.endswith("'")):
                            matched_cmd = k
                            extra_arg = rest[1:-1]
                            break

                if matched_cmd:
                    self._send_laptop(matched_cmd, dictionary[matched_cmd], extra_arg)
                    time.sleep(0.15)
                    continue

                if "(" in stmt or stmt in env:
                    safe_eval(stmt, line_num)
                    continue

                for word in stmt.split():
                    if word in dictionary:
                        self._send_laptop(word, dictionary[word])
                        time.sleep(0.15)
                    else:
                        raise RuntimeError(f"Line {line_num}: Unknown command or variable '{word}'")

        try:
            ast = self._parse_python_blocks(raw_lines)
            exec_nodes(ast)
            self.root.after(0, self._append_log, self.screen_log, "Done.")
        except Exception as err:
            self.root.after(0, self._append_log, self.screen_log, f"ERROR: {err}")
        finally:
            self.running = False


if __name__ == "__main__":
    try:
        if "--init" in sys.argv:
            ensure_files()
            sys.exit(0)
        root = tk.Tk()
        RPLStudioApp(root)
        root.mainloop()
    except Exception:
        err_msg = traceback.format_exc()
        try:
            with open(CRASH_LOG_PATH, "w", encoding="utf-8") as f:
                f.write(err_msg)
        except Exception:
            pass
        ctypes.windll.user32.MessageBoxW(0, err_msg, "RPL Studio Error", 0x10)
# ===END_RPL_PY===
