@echo off
title RPL v4.0 - Modern UI + Minecraft 3D Engine Builder
setlocal

set "SELF=%~f0"
set "RPL_DIR=%USERPROFILE%\RPL"

echo ==================================================
echo   Installing RPL Studio v4.0 into: %RPL_DIR%
echo ==================================================

taskkill /f /im rpl.exe >nul 2>&1
timeout /t 1 /nobreak >nul

if not exist "%RPL_DIR%" mkdir "%RPL_DIR%"
cd /d "%RPL_DIR%"

:: Backup library.txt
if exist "%RPL_DIR%\library.txt" copy /y "%RPL_DIR%\library.txt" "%RPL_DIR%\library.txt.bak" >nul

:: Delete old version files (and permanently remove update_url.txt!)
if exist "%RPL_DIR%\update_url.txt" del /f /q "%RPL_DIR%\update_url.txt"
if exist "%RPL_DIR%\rpl.exe" del /f /q "%RPL_DIR%\rpl.exe"
if exist "%RPL_DIR%\rpl_studio.py" del /f /q "%RPL_DIR%\rpl_studio.py"
if exist "%RPL_DIR%\rpl.ico" del /f /q "%RPL_DIR%\rpl.ico"
if exist "%RPL_DIR%\RPL_Release.zip" del /f /q "%RPL_DIR%\RPL_Release.zip"
if exist "%RPL_DIR%\main.rpl" del /f /q "%RPL_DIR%\main.rpl"
if exist "%RPL_DIR%\README.txt" del /f /q "%RPL_DIR%\README.txt"
if exist "%RPL_DIR%\library.txt" del /f /q "%RPL_DIR%\library.txt"
if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

:: Find or Auto-Install Python
set "PY_CMD=python"
python --version >nul 2>&1
if errorlevel 1 (
    py -3 --version >nul 2>&1
    if not errorlevel 1 (
        set "PY_CMD=py -3"
    ) else (
        echo Python not found. Installing Python automatically...
        winget install -e --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
        for /d %%P in ("%LOCALAPPDATA%\Programs\Python\Python3*") do set "PATH=%%P;%%P\Scripts;%PATH%"
        python --version >nul 2>&1
        if errorlevel 1 (
            powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe' -OutFile '%TEMP%\py_setup.exe'"
            "%TEMP%\py_setup.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
            for /d %%P in ("%LOCALAPPDATA%\Programs\Python\Python3*") do set "PATH=%%P;%%P\Scripts;%PATH%"
        )
    )
)

%PY_CMD% --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is required. Install from python.org and retry.
    pause
    exit /b 1
)

:: 1. Use Wi-Fi to download Modern UI + Game Engine libraries
echo Downloading Modern UI (customtkinter) and Game Engine (pygame-ce) over Wi-Fi...
%PY_CMD% -m pip install --upgrade pip pyinstaller customtkinter pillow pygame-ce
if errorlevel 1 (
    echo Retrying with standard pygame...
    %PY_CMD% -m pip install --upgrade pyinstaller customtkinter pillow pygame
)

:: 2. Extract v4.0 rpl_studio.py
powershell -NoProfile -Command "$s = '# ===BEGIN_' + 'RPL_PY==='; $e = '# ===END_' + 'RPL_PY==='; $c = Get-Content -LiteralPath $env:SELF -Raw; $m = [regex]::Match($c, '(?s)' + $s + '(.*?)' + $e); Set-Content -Path '%RPL_DIR%\rpl_studio.py' -Value $m.Groups[1].Value.Trim() -Encoding UTF8"

:: 3. Initialize hello.rpl, minecraft.rpl, library.txt, rpl.ico
%PY_CMD% "%RPL_DIR%\rpl_studio.py" --init

:: 4. Build rpl.exe (with Modern UI, Game Engine, Python & Icon bundled inside!)
echo Building rpl.exe v4.0 (please wait)...
%PY_CMD% -m PyInstaller --noconfirm --onefile --windowed --name rpl --icon="%RPL_DIR%\rpl.ico" --add-data "%RPL_DIR%\rpl.ico;." --collect-all customtkinter --hidden-import=pygame --distpath "%RPL_DIR%" --workpath "%RPL_DIR%\build" --specpath "%RPL_DIR%\build" "%RPL_DIR%\rpl_studio.py"
if errorlevel 1 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

:: 5. Add RPL folder to User PATH
powershell -NoProfile -Command "$dir = $env:RPL_DIR; $p = [Environment]::GetEnvironmentVariable('Path','User'); if ($p -notlike \"*$dir*\") { $newP = if ($p) { \"$p;$dir\" } else { $dir }; [Environment]::SetEnvironmentVariable('Path', $newP, 'User') }"

:: 6. Desktop Shortcut
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\RPL Studio.lnk'); $s.TargetPath = '%RPL_DIR%\rpl.exe'; $s.WorkingDirectory = '%RPL_DIR%'; $s.IconLocation = '%RPL_DIR%\rpl.ico'; $s.Save()"

:: 7. Build RPL_Release.zip (no update_url.txt!)
timeout /t 3 /nobreak >nul
powershell -NoProfile -Command "for ($i=1; $i -le 10; $i++) { try { Compress-Archive -Path '%RPL_DIR%\rpl.exe','%RPL_DIR%\library.txt','%RPL_DIR%\hello.rpl','%RPL_DIR%\minecraft.rpl','%RPL_DIR%\README.txt' -DestinationPath '%RPL_DIR%\RPL_Release.zip' -Force -ErrorAction Stop; break } catch { Write-Host 'Waiting for Antivirus scan...'; Start-Sleep -Seconds 2 } }"

echo.
echo ==================================================
echo   RPL v4.0 READY!
echo   - Modern Wi-Fi UI installed!
echo   - 3D Minecraft demo ready: minecraft.rpl
echo   - update_url.txt removed!
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
import math as py_math
import struct
import shutil
import ctypes
import random
import traceback
import threading
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox

os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "1"

import customtkinter as ctk

try:
    import winsound
except ImportError:
    winsound = None

VERSION = "4.0"

if getattr(sys, "frozen", False):
    APP_DIR = os.path.dirname(sys.executable)
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))

LIB_PATH = os.path.join(APP_DIR, "library.txt")
LIB_BACKUP_PATH = os.path.join(APP_DIR, "library.txt.bak")
HELLO_PATH = os.path.join(APP_DIR, "hello.rpl")
MINECRAFT_PATH = os.path.join(APP_DIR, "minecraft.rpl")
README_PATH = os.path.join(APP_DIR, "README.txt")
ICON_PATH = os.path.join(APP_DIR, "rpl.ico")
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

DEFAULT_HELLO = """// hello.rpl - Write RPL just like Python!
use math
use text

name = "Ridwaan"
items = ["pickaxe", "wood", "diamond"]

go "Hello " + name + "!"
go("Uppercase: " + text.upper(name))
go("Inventory: " + str(items))

for i in range(len(items)):
    go "Slot " + str(i + 1) + ": " + items[i]

def roll_loot():
    n = math.rand(1, 100)
    if n > 50:
        return "Rare Diamond (" + str(n) + ")"
    return "Stone (" + str(n) + ")"

go "Loot Roll -> " + roll_loot()
hello
beep
"""

DEFAULT_MINECRAFT = """// minecraft.rpl - Fan-Made 3D Minecraft written in RPL!
// Controls:
//   WASD = Walk | Space = Jump | Shift = Sprint | Mouse = Look
//   Left Click = Break Block | Right Click = Place Block
//   Keys 1-9 or Scroll = Switch Block | E / ESC = Unlock Mouse

use voxel3d
use math

go "Building 3D Minecraft world..."
world = voxel3d.World(title="RPL Craft (Fan-Made Minecraft)", width=1080, height=680)

// Generate hills with grass, dirt, and stone
for x in range(-9, 10):
    for z in range(-9, 10):
        h = int(2 + math.sin(x * 0.45) * 1.4 + math.cos(z * 0.45) * 1.4)
        for y in range(0, h + 1):
            if y == h:
                world.set_block(x, y, z, "grass")
            elif y >= h - 1:
                world.set_block(x, y, z, "dirt")
            else:
                world.set_block(x, y, z, "stone")

        // Plant trees!
        if (x == 3 and z == 3) or (x == -4 and z == 2) or (x == 2 and z == -5):
            for ty in range(1, 4):
                world.set_block(x, h + ty, z, "wood")
            for lx in range(-1, 2):
                for lz in range(-1, 2):
                    world.set_block(x + lx, h + 4, z + lz, "leaves")
            world.set_block(x, h + 5, z, "leaves")

// Build a small brick & diamond tower to explore!
for ty in range(4, 7):
    world.set_block(0, ty, 5, "brick")
world.set_block(0, 7, 5, "diamond")
world.set_block(1, 4, 5, "gold")

// Custom script hook: print when player breaks a diamond!
def on_block_broken(bx, by, bz, btype):
    if btype == "diamond":
        go "Awesome! You mined a DIAMOND at " + str((bx, by, bz)) + "!"

world.on_break(on_block_broken)
world.set_spawn(0, 7, 0)
world.run()
"""

DEFAULT_README = """RPL v4.0 (Ridwaan Programming Language)
=======================================
1. Double-click rpl.exe to open RPL Studio (Modern UI + Python + 3D Game Engine built in!).
2. Switch between hello.rpl and minecraft.rpl at the top, or open any .rpl file.
3. Click "Library Base" to see how to build 2D games (use game) and 3D Minecraft (use voxel3d).
4. Updating library.txt: Download a new library.txt to your Downloads folder and click "Update .txt".
"""


def generate_rpl_ico(out_path):
    size = 64
    canvas = [[(0, 0, 0, 0) for _ in range(size)] for _ in range(size)]

    def dist_rounded(x, y, s, r):
        cx = max(r, min(s - 1 - r, x))
        cy = max(r, min(s - 1 - r, y))
        return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5

    for y in range(size):
        for x in range(size):
            d = dist_rounded(x, y, size, 12)
            if d <= 12.2:
                t = (x + y) / (2.0 * (size - 1))
                br = int(56 * (1 - t) + 52 * t)
                bg = int(189 * (1 - t) + 211 * t)
                bb = int(248 * (1 - t) + 153 * t)
                if d >= 9.2:
                    canvas[y][x] = (bb, bg, br, 255)
                else:
                    ir = int(10 + 8 * t)
                    ig = int(18 + 12 * t)
                    ib = int(42 + 16 * t)
                    canvas[y][x] = (ib, ig, ir, 255)

    font = {
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    }
    colors = {
        "R": (248, 189, 56, 255),
        "P": (255, 255, 255, 255),
        "L": (153, 211, 52, 255),
    }

    scale = 3
    start_x, start_y = 7, 21
    for idx, ch in enumerate("RPL"):
        ox = start_x + idx * (5 * scale + 2)
        col = colors[ch]
        for ry, row in enumerate(font[ch]):
            for rx, bit in enumerate(row):
                if bit == "1":
                    for dy in range(scale):
                        for dx in range(scale):
                            px, py = ox + rx * scale + dx, start_y + ry * scale + dy
                            if 0 <= px < size and 0 <= py < size:
                                canvas[py][px] = col

    def downsample(target_s):
        if target_s == size:
            return canvas
        factor = size // target_s
        out = [[(0, 0, 0, 0) for _ in range(target_s)] for _ in range(target_s)]
        for y in range(target_s):
            for x in range(target_s):
                sb = sg = sr = sa = 0
                for dy in range(factor):
                    for dx in range(factor):
                        b, g, r, a = canvas[y * factor + dy][x * factor + dx]
                        sb += b; sg += g; sr += r; sa += a
                n = factor * factor
                out[y][x] = (sb // n, sg // n, sr // n, sa // n)
        return out

    sizes = [16, 32, 64]
    entries, blobs = [], []
    offset = 6 + 16 * len(sizes)
    for s in sizes:
        img = downsample(s)
        pixels = bytearray()
        for y in range(s - 1, -1, -1):
            for x in range(s):
                pixels.extend(img[y][x])
        row_mask_bytes = ((s + 31) // 32) * 4
        mask = b"\x00" * (row_mask_bytes * s)
        header = struct.pack("<IIIHHIIIIII", 40, s, s * 2, 1, 32, 0, len(pixels) + len(mask), 0, 0, 0, 0)
        dib = header + bytes(pixels) + mask
        entries.append(struct.pack("<BBBBHHII", s, s, 0, 0, 1, 32, len(dib), offset))
        blobs.append(dib)
        offset += len(dib)

    with open(out_path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(sizes)) + b"".join(entries) + b"".join(blobs))


def get_icon_path():
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        bundled = os.path.join(sys._MEIPASS, "rpl.ico")
        if os.path.exists(bundled):
            return bundled
    return ICON_PATH


def ensure_files():
    defaults = [
        (LIB_PATH, DEFAULT_LIB),
        (HELLO_PATH, DEFAULT_HELLO),
        (MINECRAFT_PATH, DEFAULT_MINECRAFT),
        (README_PATH, DEFAULT_README),
    ]
    for path, content in defaults:
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
    if not os.path.exists(ICON_PATH):
        generate_rpl_ico(ICON_PATH)


def validate_library_text(content):
    head = content[:500].lower()
    if "<html" in head or "<!doctype" in head:
        return False, "File is HTML, not a valid library.txt."
    count = 0
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        if ":" in line:
            w, r = line.split(":", 1)
            if w.strip() and r.strip():
                count += 1
    if count == 0:
        return False, "No valid 'command:binary' lines found."
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


def parse_library_content(text):
    dictionary, meta = {}, {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        if ":" in line:
            word, rest = line.split(":", 1)
            word = word.strip()
            code, desc = rest.split("|", 1) if "|" in rest else (rest, "")
            code, desc = code.strip(), desc.strip()
            if word:
                dictionary[word] = code
                meta[word] = {"code": code, "desc": desc}
    return dictionary, meta


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


def replace_slash_comments(line):
    in_quote = None
    out = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch in ('"', "'") and (i == 0 or line[i - 1] != "\\"):
            if in_quote == ch:
                in_quote = None
            elif in_quote is None:
                in_quote = ch
            out.append(ch)
        elif in_quote is None and ch == "/" and i + 1 < len(line) and line[i + 1] == "/":
            out.append("#" + line[i + 2:])
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def preprocess_rpl(code_text, dictionary):
    sorted_keys = sorted(dictionary.keys(), key=len, reverse=True)
    out_lines = []
    bracket_depth = 0

    for raw in code_text.splitlines():
        line = replace_slash_comments(raw)
        stripped = line.strip()
        indent = line[:len(line) - len(line.lstrip(" \t"))]

        if bracket_depth == 0 and stripped and not stripped.startswith("#"):
            # Strip trailing inline comment for matching
            code_part = stripped
            in_q = None
            for idx_c, c in enumerate(stripped):
                if c in ('"', "'") and (idx_c == 0 or stripped[idx_c - 1] != "\\"):
                    in_q = None if in_q == c else (in_q or c)
                elif in_q is None and c == "#":
                    code_part = stripped[:idx_c].strip()
                    break

            if code_part.startswith("use ") or code_part.startswith("import "):
                lib_name = code_part.split(None, 1)[1].strip()
                line = f'{indent}__rpl_use__("{lib_name}")'
            elif code_part == "go":
                line = f'{indent}go("")'
            elif code_part.startswith("go "):
                arg = code_part[3:].strip()
                if arg in dictionary:
                    line = f'{indent}__rpl_go_key__({repr(arg)}, globals())'
                else:
                    line = f'{indent}go({arg})'
            else:
                # Match library.txt commands
                matched = None
                extra_arg = None
                for k in sorted_keys:
                    if code_part == k:
                        matched = k
                        break
                    elif code_part.startswith(k + " "):
                        rest = code_part[len(k):].strip()
                        if (rest.startswith('"') and rest.endswith('"')) or (rest.startswith("'") and rest.endswith("'")):
                            matched = k
                            extra_arg = rest
                            break
                if matched:
                    if extra_arg:
                        line = f'{indent}__rpl_cmd__({repr(matched)}, {extra_arg})'
                    else:
                        line = f'{indent}__rpl_cmd__({repr(matched)})'

        out_lines.append(line)
        # Update bracket depth (outside quotes/comments)
        in_q = None
        for idx_c, c in enumerate(line):
            if c in ('"', "'") and (idx_c == 0 or line[idx_c - 1] != "\\"):
                in_q = None if in_q == c else (in_q or c)
            elif in_q is None:
                if c == "#":
                    break
                if c in "([{":
                    bracket_depth += 1
                elif c in ")]}":
                    bracket_depth = max(0, bracket_depth - 1)

    return "\n".join(out_lines)


# ==========================================
# RPL STANDARD & GAME LIBRARIES
# ==========================================
class MathLib:
    pi = round(py_math.pi, 5)
    def rand(self, a=1, b=10): return random.randint(int(a), int(b))
    def sqrt(self, x): return py_math.sqrt(x)
    def sin(self, x): return py_math.sin(x)
    def cos(self, x): return py_math.cos(x)
    def floor(self, x): return py_math.floor(x)
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


class Game2DLib:
    def __init__(self):
        import pygame
        self.pg = pygame
        self.screen = None
        self.clock = None
        self.running = False
        self.fonts = {}

    def start(self, width=900, height=600, title="RPL Game", fps=60):
        self.pg.init()
        self.screen = self.pg.display.set_mode((int(width), int(height)))
        self.pg.display.set_caption(str(title))
        ico = get_icon_path()
        if os.path.exists(ico):
            try:
                self.pg.display.set_icon(self.pg.image.load(ico))
            except Exception:
                pass
        self.clock = self.pg.time.Clock()
        self.fps = int(fps)
        self.running = True

    def clear(self, r=15, g=23, b=42):
        if self.screen:
            self.screen.fill((int(r), int(g), int(b)))

    def rect(self, x, y, w, h, color=(52, 211, 153)):
        if self.screen:
            self.pg.draw.rect(self.screen, color, (int(x), int(y), int(w), int(h)))

    def circle(self, x, y, radius, color=(56, 189, 248)):
        if self.screen:
            self.pg.draw.circle(self.screen, color, (int(x), int(y)), int(radius))

    def text(self, msg, x, y, size=24, color=(255, 255, 255)):
        if self.screen:
            s = int(size)
            if s not in self.fonts:
                self.fonts[s] = self.pg.font.SysFont("consolas", s, bold=True)
            surf = self.fonts[s].render(str(msg), True, color)
            self.screen.blit(surf, (int(x), int(y)))

    def key(self, name):
        keys = self.pg.key.get_pressed()
        kmap = {
            "w": self.pg.K_w, "a": self.pg.K_a, "s": self.pg.K_s, "d": self.pg.K_d,
            "up": self.pg.K_UP, "down": self.pg.K_DOWN, "left": self.pg.K_LEFT, "right": self.pg.K_RIGHT,
            "space": self.pg.K_SPACE, "shift": self.pg.K_LSHIFT, "esc": self.pg.K_ESCAPE,
            "1": self.pg.K_1, "2": self.pg.K_2, "3": self.pg.K_3, "4": self.pg.K_4,
        }
        code = kmap.get(str(name).lower())
        return bool(code and keys[code])

    def mouse_x(self): return self.pg.mouse.get_pos()[0]
    def mouse_y(self): return self.pg.mouse.get_pos()[1]
    def mouse_down(self, btn=1): return bool(self.pg.mouse.get_pressed()[btn - 1])
    def stop(self): self.running = False

    def loop(self, update_fn):
        if not self.screen:
            self.start()
        while self.running:
            dt = self.clock.tick(self.fps) / 1000.0
            for ev in self.pg.event.get():
                if ev.type == self.pg.QUIT:
                    self.running = False
            update_fn(dt)
            self.pg.display.flip()
        self.pg.quit()


class Voxel3DWorld:
    PALETTE = {
        "grass":   ((94, 186, 68), (134, 96, 67)),   # (top_color, side_color)
        "dirt":    ((134, 96, 67), (120, 84, 58)),
        "stone":   ((132, 136, 142), (118, 122, 128)),
        "wood":    ((166, 126, 76), (118, 82, 46)),
        "leaves":  ((54, 142, 58), (44, 120, 48)),
        "diamond": ((68, 228, 236), (52, 200, 212)),
        "gold":    ((248, 210, 62), (222, 182, 44)),
        "brick":   ((178, 78, 62), (156, 66, 52)),
        "water":   ((56, 136, 236), (48, 120, 214)),
    }
    HOTBAR_ORDER = ["grass", "dirt", "stone", "wood", "leaves", "brick", "gold", "diamond", "water"]

    def __init__(self, title="RPL Craft (Fan-Made Minecraft)", width=1080, height=680):
        self.title = str(title)
        self.width = int(width)
        self.height = int(height)
        self.blocks = {}
        self.spawn = [0.5, 6.0, 0.5]
        self.on_update_cb = None
        self.on_break_cb = None
        self.on_place_cb = None

    def set_block(self, x, y, z, btype="grass"):
        btype = str(btype).lower()
        if btype == "air":
            self.blocks.pop((int(x), int(y), int(z)), None)
        else:
            self.blocks[(int(x), int(y), int(z))] = btype

    def get_block(self, x, y, z):
        return self.blocks.get((int(x), int(y), int(z)), "air")

    def remove_block(self, x, y, z):
        return self.blocks.pop((int(x), int(y), int(z)), None)

    def set_spawn(self, x, y, z):
        self.spawn = [float(x) + 0.5, float(y), float(z) + 0.5]

    def on_update(self, fn): self.on_update_cb = fn
    def on_break(self, fn): self.on_break_cb = fn
    def on_place(self, fn): self.on_place_cb = fn

    def _clip_near(self, poly, near=0.15):
        out = []
        n = len(poly)
        for i in range(n):
            a = poly[i]
            b = poly[(i + 1) % n]
            a_in = a[2] >= near
            b_in = b[2] >= near
            if a_in:
                out.append(a)
                if not b_in:
                    t = (near - a[2]) / (b[2] - a[2])
                    out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]), near))
            elif b_in:
                t = (near - a[2]) / (b[2] - a[2])
                out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]), near))
        return out

    def _collides(self, px, py, pz):
        r = 0.28
        h = 1.75
        min_x = py_math.floor(px - r)
        max_x = py_math.floor(px + r)
        min_y = py_math.floor(py)
        max_y = py_math.floor(py + h)
        min_z = py_math.floor(pz - r)
        max_z = py_math.floor(pz + r)
        for bx in range(min_x, max_x + 1):
            for by in range(min_y, max_y + 1):
                for bz in range(min_z, max_z + 1):
                    if (bx, by, bz) in self.blocks:
                        return True
        return False

    def _raycast(self, cx, cy, cz, lx, ly, lz, max_dist=5.5):
        prev = None
        step = 0.05
        t = 0.2
        while t <= max_dist:
            px, py, pz = cx + lx * t, cy + ly * t, cz + lz * t
            cell = (py_math.floor(px), py_math.floor(py), py_math.floor(pz))
            if cell in self.blocks:
                return cell, prev
            prev = cell
            t += step
        return None, None

    def run(self):
        import pygame
        pygame.init()
        screen = pygame.display.set_mode((self.width, self.height))
        pygame.display.set_caption(self.title)
        ico = get_icon_path()
        if os.path.exists(ico):
            try:
                pygame.display.set_icon(pygame.image.load(ico))
            except Exception:
                pass

        clock = pygame.time.Clock()
        font = pygame.font.SysFont("consolas", 15, bold=True)
        font_sm = pygame.font.SysFont("consolas", 12, bold=True)

        px, py, pz = list(self.spawn)
        vy = 0.0
        on_ground = False
        yaw = 0.0
        pitch = -0.15
        selected_idx = 0

        mouse_locked = True
        pygame.mouse.set_visible(False)
        pygame.event.set_grab(True)
        pygame.mouse.get_rel()

        half_w = self.width / 2.0
        half_h = self.height / 2.0
        fov = self.height * 0.85

        # Face definitions: (normal, 4 corners offsets, shade multiplier, is_top)
        FACES = [
            ((0, 1, 0),  ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)), 1.00, True),
            ((0, -1, 0), ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)), 0.55, False),
            ((1, 0, 0),  ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)), 0.82, False),
            ((-1, 0, 0), ((0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)), 0.82, False),
            ((0, 0, 1),  ((1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)), 0.70, False),
            ((0, 0, -1), ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)), 0.70, False),
        ]

        sky = (128, 194, 255)
        running = True

        while running:
            dt = min(clock.tick(60) / 1000.0, 0.05)

            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    running = False
                elif ev.type == pygame.KEYDOWN:
                    if ev.key in (pygame.K_ESCAPE, pygame.K_e):
                        mouse_locked = not mouse_locked
                        pygame.mouse.set_visible(not mouse_locked)
                        pygame.event.set_grab(mouse_locked)
                        pygame.mouse.get_rel()
                    elif pygame.K_1 <= ev.key <= pygame.K_9:
                        selected_idx = ev.key - pygame.K_1
                elif ev.type == pygame.MOUSEWHEEL:
                    selected_idx = (selected_idx - ev.y) % len(self.HOTBAR_ORDER)
                elif ev.type == pygame.MOUSEBUTTONDOWN:
                    if not mouse_locked:
                        mouse_locked = True
                        pygame.mouse.set_visible(False)
                        pygame.event.set_grab(True)
                        pygame.mouse.get_rel()
                    else:
                        eye_y = py + 1.55
                        lx = py_math.sin(yaw) * py_math.cos(pitch)
                        ly = py_math.sin(pitch)
                        lz = py_math.cos(yaw) * py_math.cos(pitch)
                        hit, prev = self._raycast(px, eye_y, pz, lx, ly, lz)
                        if ev.button == 1 and hit:
                            btype = self.blocks.pop(hit, None)
                            if btype and self.on_break_cb:
                                self.on_break_cb(hit[0], hit[1], hit[2], btype)
                        elif ev.button == 3 and prev:
                            btype = self.HOTBAR_ORDER[selected_idx]
                            self.blocks[prev] = btype
                            if self._collides(px, py, pz):
                                self.blocks.pop(prev, None)
                            elif self.on_place_cb:
                                self.on_place_cb(prev[0], prev[1], prev[2], btype)

            # Mouse Look
            if mouse_locked:
                mx, my = pygame.mouse.get_rel()
                yaw += mx * 0.0028
                pitch = max(-1.45, min(1.45, pitch - my * 0.0028))

            # Movement
            keys = pygame.key.get_pressed()
            speed = 7.2 if keys[pygame.K_LSHIFT] else 4.6
            fx, fz = py_math.sin(yaw), py_math.cos(yaw)
            rx, rz = py_math.cos(yaw), -py_math.sin(yaw)
            mv_x = mv_z = 0.0
            if keys[pygame.K_w]: mv_x += fx; mv_z += fz
            if keys[pygame.K_s]: mv_x -= fx; mv_z -= fz
            if keys[pygame.K_d]: mv_x += rx; mv_z += rz
            if keys[pygame.K_a]: mv_x -= rx; mv_z -= rz

            mag = (mv_x * mv_x + mv_z * mv_z) ** 0.5
            if mag > 0:
                mv_x = (mv_x / mag) * speed * dt
                mv_z = (mv_z / mag) * speed * dt
                if not self._collides(px + mv_x, py, pz):
                    px += mv_x
                if not self._collides(px, py, pz + mv_z):
                    pz += mv_z

            # Gravity & Jump
            if on_ground and keys[pygame.K_SPACE]:
                vy = 8.4
                on_ground = False

            vy -= 22.0 * dt
            dy_step = vy * dt
            if not self._collides(px, py + dy_step, pz):
                py += dy_step
                on_ground = False
            else:
                if vy < 0:
                    on_ground = True
                vy = 0.0

            if py < -15:
                px, py, pz = list(self.spawn)
                vy = 0.0

            if self.on_update_cb:
                self.on_update_cb(self, dt)

            # Camera / Raycast
            cam_x, cam_y, cam_z = px, py + 1.55, pz
            sin_y, cos_y = py_math.sin(yaw), py_math.cos(yaw)
            sin_p, cos_p = py_math.sin(pitch), py_math.cos(pitch)
            lx = sin_y * cos_p
            ly = sin_p
            lz = cos_y * cos_p
            target_hit, _ = self._raycast(cam_x, cam_y, cam_z, lx, ly, lz)

            # Render Sky & Ground Horizon
            screen.fill(sky)

            # Collect & Cull Visible Faces
            render_list = []
            max_r2 = 100.0  # 10 blocks radius

            for (bx, by, bz), btype in self.blocks.items():
                dx_c = (bx + 0.5) - cam_x
                dy_c = (by + 0.5) - cam_y
                dz_c = (bz + 0.5) - cam_z
                dist2 = dx_c * dx_c + dy_c * dy_c + dz_c * dz_c
                if dist2 > max_r2:
                    continue
                # Frustum roughly in front of camera
                if dist2 > 2.5 and (dx_c * lx + dy_c * ly + dz_c * lz) < -0.35 * (dist2 ** 0.5):
                    continue

                top_col, side_col = self.PALETTE.get(btype, ((200, 200, 200), (160, 160, 160)))
                is_target = (bx, by, bz) == target_hit

                for (nx, ny, nz), corners, shade, is_top in FACES:
                    # Neighbor occlusion culling
                    if (bx + nx, by + ny, bz + nz) in self.blocks:
                        continue
                    # Backface culling
                    fcx = bx + 0.5 + nx * 0.5
                    fcy = by + 0.5 + ny * 0.5
                    fcz = bz + 0.5 + nz * 0.5
                    if (cam_x - fcx) * nx + (cam_y - fcy) * ny + (cam_z - fcz) * nz <= 0:
                        continue

                    # Transform 4 corners into camera space
                    cam_poly = []
                    for ox, oy, oz in corners:
                        wx = (bx + ox) - cam_x
                        wy = (by + oy) - cam_y
                        wz = (bz + oz) - cam_z
                        x1 = wx * cos_y - wz * sin_y
                        z1 = wx * sin_y + wz * cos_y
                        y2 = wy * cos_p - z1 * sin_p
                        z2 = wy * sin_p + z1 * cos_p
                        cam_poly.append((x1, y2, z2))

                    clipped = self._clip_near(cam_poly, 0.15)
                    if len(clipped) < 3:
                        continue

                    pts2d = [(half_w + (vx / vz) * fov, half_h - (vy_ / vz) * fov) for vx, vy_, vz in clipped]

                    base = top_col if is_top else side_col
                    fog = min(0.6, max(0.0, (dist2 - 36.0) / 85.0))
                    r = int((base[0] * shade) * (1 - fog) + sky[0] * fog)
                    g = int((base[1] * shade) * (1 - fog) + sky[1] * fog)
                    b = int((base[2] * shade) * (1 - fog) + sky[2] * fog)
                    fdist2 = (fcx - cam_x) ** 2 + (fcy - cam_y) ** 2 + (fcz - cam_z) ** 2
                    render_list.append((fdist2, pts2d, (r, g, b), is_target))

            # Painter's Algorithm (Back-to-Front)
            render_list.sort(key=lambda item: item[0], reverse=True)
            for _, pts2d, col, is_target in render_list:
                pygame.draw.polygon(screen, col, pts2d)
                pygame.draw.polygon(screen, (255, 255, 255) if is_target else (30, 35, 45), pts2d, 2 if is_target else 1)

            # Crosshair
            pygame.draw.line(screen, (255, 255, 255), (half_w - 8, half_h), (half_w + 8, half_h), 2)
            pygame.draw.line(screen, (255, 255, 255), (half_w, half_h - 8), (half_w, half_h + 8), 2)

            # Top HUD
            hud = f"RPL Craft | FPS: {int(clock.get_fps())} | XYZ: ({int(px)}, {int(py)}, {int(pz)}) | {'[ESC] Unlock Mouse' if mouse_locked else 'Click Window to Play'}"
            hud_surf = font.render(hud, True, (255, 255, 255))
            pygame.draw.rect(screen, (15, 23, 42), (8, 8, hud_surf.get_width() + 16, 28), border_radius=6)
            screen.blit(hud_surf, (16, 13))

            # Hotbar (1-9)
            slot_w, slot_h, gap = 52, 52, 6
            total_w = len(self.HOTBAR_ORDER) * (slot_w + gap) - gap
            start_x = (self.width - total_w) // 2
            bar_y = self.height - 68
            for idx, bname in enumerate(self.HOTBAR_ORDER):
                sx = start_x + idx * (slot_w + gap)
                is_sel = idx == selected_idx
                pygame.draw.rect(screen, (30, 41, 59), (sx, bar_y, slot_w, slot_h), border_radius=6)
                pygame.draw.rect(screen, (56, 189, 248) if is_sel else (71, 85, 105), (sx, bar_y, slot_w, slot_h), 3 if is_sel else 1, border_radius=6)
                top_c, _ = self.PALETTE[bname]
                pygame.draw.rect(screen, top_c, (sx + 12, bar_y + 10, 28, 22), border_radius=3)
                num_s = font_sm.render(str(idx + 1), True, (255, 255, 255))
                screen.blit(num_s, (sx + 4, bar_y + 2))
                lbl_s = font_sm.render(bname[:5], True, (226, 232, 240))
                screen.blit(lbl_s, (sx + 6, bar_y + 34))

            pygame.display.flip()

        pygame.quit()


class Voxel3DLib:
    World = Voxel3DWorld


class UILib:
    def __init__(self, emit_fn):
        self.emit = emit_fn
    def window(self, title="RPL Window", message="Opened from RPL ui.window()"):
        self.emit("UIWIN", f"{title}||{message}")
    def alert(self, title="RPL Alert", message="Hello!"):
        self.emit("ALERT", f"{title}||{message}")


# ==========================================
# SHARED RPL CODE RUNNER (In-process or Subprocess)
# ==========================================
def run_rpl_code(code_text, lib_text, emit_fn):
    dictionary, _ = parse_library_content(lib_text)
    env = {"__builtins__": {
        "print": print, "str": str, "int": int, "float": float, "bool": bool,
        "list": list, "dict": dict, "set": set, "tuple": tuple,
        "len": len, "range": range, "enumerate": enumerate, "zip": zip,
        "min": min, "max": max, "abs": abs, "round": round, "sum": sum, "sorted": sorted,
        "isinstance": isinstance, "object": object, "super": super,
        "Exception": Exception, "ValueError": ValueError, "KeyError": KeyError,
        "__build_class__": __build_class__, "__name__": "__main__",
    }}

    def send_bin(word, binary, extra=""):
        emit_fn("BIN", f"{word}|{binary}|{extra}")

    def rpl_go(*args):
        if "go" in dictionary:
            send_bin("go", dictionary["go"])
        out_str = " ".join(str(a) for a in args)
        emit_fn("GO", out_str)
        if out_str:
            send_bin(f'"{out_str}"', encode_binary(out_str))

    def rpl_go_key(key, scope):
        if key in scope:
            rpl_go(scope[key])
        else:
            if "go" in dictionary:
                send_bin("go", dictionary["go"])
            b = dictionary[key]
            emit_fn("GO", b)
            send_bin(key, b)

    def rpl_cmd(cmd, extra=""):
        if cmd in dictionary:
            send_bin(cmd, dictionary[cmd], str(extra))

    def rpl_use(lib_name):
        if lib_name == "math":
            env["math"] = MathLib()
        elif lib_name == "text":
            env["text"] = TextLib()
        elif lib_name == "time":
            env["time"] = TimeLib()
        elif lib_name == "ui":
            env["ui"] = UILib(emit_fn)
        elif lib_name == "game":
            env["game"] = Game2DLib()
        elif lib_name == "voxel3d":
            env["voxel3d"] = Voxel3DLib()
        else:
            raise ImportError(f"Unknown RPL library '{lib_name}'. Check Library Base!")

    env["go"] = rpl_go
    env["__rpl_go_key__"] = rpl_go_key
    env["__rpl_cmd__"] = rpl_cmd
    env["__rpl_use__"] = rpl_use

    py_code = preprocess_rpl(code_text, dictionary)
    compiled = compile(py_code, "<rpl>", "exec")
    exec(compiled, env, env)


def run_cli_subprocess(rpl_file_path):
    with open(rpl_file_path, "r", encoding="utf-8") as f:
        code_text = f.read()
    lib_text = DEFAULT_LIB
    if os.path.exists(LIB_PATH):
        with open(LIB_PATH, "r", encoding="utf-8") as f:
            lib_text = f.read()

    def emit(kind, payload):
        safe_payload = str(payload).replace("\n", "\\n")
        print(f"__RPL_{kind}__:{safe_payload}", flush=True)

    try:
        run_rpl_code(code_text, lib_text, emit)
        emit("DONE", "Done.")
    except Exception as e:
        emit("ERR", f"{type(e).__name__}: {e}")


# ==========================================
# MODERN WI-FI UI (CustomTkinter)
# ==========================================
class RPLStudioApp:
    def __init__(self, root):
        self.root = root
        self.root.title(f"RPL Studio v{VERSION} - Ridwaan Programming Language")
        self.root.geometry("1320x790")
        self.game_proc = None
        self.current_rpl_path = HELLO_PATH
        self.pure_binary_var = tk.BooleanVar(value=True)

        ensure_files()
        ico = get_icon_path()
        if os.path.exists(ico):
            try:
                self.root.iconbitmap(ico)
            except Exception:
                pass

        self._build_ui()
        self.load_files()

        self.root.bind("<Control-s>", lambda e: self.save_files())
        self.root.after(450, self.check_downloads_update)

    def _build_ui(self):
        # Top Navigation Bar
        top = ctk.CTkFrame(self.root, height=64, corner_radius=12, fg_color="#11182d")
        top.pack(fill="x", padx=14, pady=(12, 8))

        left_box = ctk.CTkFrame(top, fg_color="transparent")
        left_box.pack(side="left", padx=14, pady=8)
        ctk.CTkLabel(left_box, text=f"RPL STUDIO v{VERSION}", font=ctk.CTkFont("Segoe UI", 18, "bold"), text_color="#38bdf8").pack(anchor="w")
        ctk.CTkLabel(left_box, text="Python-Strength Coding  |  3D Minecraft & 2D Game Engine  |  Real 8-Bit Binary", font=ctk.CTkFont("Segoe UI", 11), text_color="#94a3b8").pack(anchor="w")

        right_box = ctk.CTkFrame(top, fg_color="transparent")
        right_box.pack(side="right", padx=12, pady=10)

        self.file_switch = ctk.CTkOptionMenu(
            right_box, values=["hello.rpl", "minecraft.rpl", "Open Other..."],
            command=self.on_file_menu, width=140, fg_color="#1e293b", button_color="#334155"
        )
        self.file_switch.pack(side="left", padx=4)

        ctk.CTkButton(right_box, text="Library Base", command=self.open_library_base, width=110, fg_color="#2563eb", hover_color="#1d4ed8").pack(side="left", padx=4)
        ctk.CTkButton(right_box, text="Update .txt", command=self.manual_import_downloads, width=105, fg_color="#0f766e", hover_color="#0d9488").pack(side="left", padx=4)
        ctk.CTkButton(right_box, text="Save", command=self.save_files, width=75, fg_color="#1e293b", hover_color="#334155").pack(side="left", padx=4)
        ctk.CTkButton(right_box, text="Stop", command=self.stop_rpl, width=70, fg_color="#7f1d1d", hover_color="#991b1b").pack(side="left", padx=4)
        ctk.CTkButton(right_box, text="Run RPL", command=self.start_rpl, width=105, fg_color="#10b981", hover_color="#059669", text_color="#042f2e", font=ctk.CTkFont("Segoe UI", 13, "bold")).pack(side="left", padx=(6, 0))

        # Main 3 Columns
        main = ctk.CTkFrame(self.root, fg_color="transparent")
        main.pack(fill="both", expand=True, padx=14, pady=(0, 14))
        main.grid_columnconfigure(0, weight=1)
        main.grid_columnconfigure(1, weight=2)
        main.grid_columnconfigure(2, weight=1)
        main.grid_rowconfigure(0, weight=1)

        # Col 1: library.txt
        c1 = ctk.CTkFrame(main, corner_radius=12, fg_color="#11182d")
        c1.grid(row=0, column=0, sticky="nsew", padx=(0, 6))
        c1_head = ctk.CTkFrame(c1, fg_color="#17203d", corner_radius=10)
        c1_head.pack(fill="x", padx=8, pady=(8, 4))
        ctk.CTkLabel(c1_head, text="library.txt (8-Bit Binary)", font=ctk.CTkFont("Segoe UI", 13, "bold")).pack(side="left", padx=10, pady=6)
        ctk.CTkButton(c1_head, text="Reload", width=60, height=24, command=self.reload_library_from_disk, fg_color="#273663").pack(sid
