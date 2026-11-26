@echo off
title RPL v5.0 - Easy 3D Coordinates + .png Textures + Complete Engine
setlocal

set "SELF=%~f0"
set "RPL_DIR=%USERPROFILE%\RPL"

echo ==================================================
echo   Installing RPL Studio v5.0 into: %RPL_DIR%
echo ==================================================

taskkill /f /im rpl.exe >nul 2>&1
timeout /t 1 /nobreak >nul

if not exist "%RPL_DIR%" mkdir "%RPL_DIR%"
cd /d "%RPL_DIR%"

if exist "%RPL_DIR%\library.txt" copy /y "%RPL_DIR%\library.txt" "%RPL_DIR%\library.txt.bak" >nul
if exist "%RPL_DIR%\hello.rpl" copy /y "%RPL_DIR%\hello.rpl" "%RPL_DIR%\hello.rpl.bak" >nul
if exist "%RPL_DIR%\update_url.txt" del /f /q "%RPL_DIR%\update_url.txt"
if exist "%RPL_DIR%\rpl.exe" del /f /q "%RPL_DIR%\rpl.exe"
if exist "%RPL_DIR%\rpl_studio.py" del /f /q "%RPL_DIR%\rpl_studio.py"
if exist "%RPL_DIR%\RPL_Release.zip" del /f /q "%RPL_DIR%\RPL_Release.zip"
if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

set "PY_CMD=python"
python --version >nul 2>&1
if errorlevel 1 (
    py -3 --version >nul 2>&1
    if not errorlevel 1 (
        set "PY_CMD=py -3"
    ) else (
        echo Installing Python...
        winget install -e --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
        for /d %%P in ("%LOCALAPPDATA%\Programs\Python\Python3*") do set "PATH=%%P;%%P\Scripts;%PATH%"
    )
)

%PY_CMD% -c "import customtkinter, darkdetect, PIL, pygame, PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo Downloading UI and Game Engine libraries over Wi-Fi...
    %PY_CMD% -m pip install pyinstaller customtkinter darkdetect packaging pillow pygame-ce
    if errorlevel 1 %PY_CMD% -m pip install pyinstaller customtkinter darkdetect packaging pillow pygame
) else (
    echo [FAST] Libraries already installed! Skipping download.
)

powershell -NoProfile -Command "$s = '# ===BEGIN_' + 'RPL_PY==='; $e = '# ===END_' + 'RPL_PY==='; $c = Get-Content -LiteralPath $env:SELF -Raw; $m = [regex]::Match($c, '(?s)' + $s + '(.*?)' + $e); Set-Content -Path '%RPL_DIR%\rpl_studio.py' -Value $m.Groups[1].Value.Trim() -Encoding UTF8"

%PY_CMD% "%RPL_DIR%\rpl_studio.py" --init-update
if errorlevel 1 (
    echo [ERROR] Init failed!
    pause
    exit /b 1
)

echo Building rpl.exe v5.0...
%PY_CMD% -m PyInstaller --noconfirm --onefile --windowed --name rpl --icon="%RPL_DIR%\rpl.ico" --add-data "%RPL_DIR%\rpl.ico;." --collect-all customtkinter --collect-all darkdetect --collect-all pygame --hidden-import=PIL._tkinter_imaging --distpath "%RPL_DIR%" --workpath "%RPL_DIR%\build" --specpath "%RPL_DIR%\build" "%RPL_DIR%\rpl_studio.py"
if errorlevel 1 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

if exist "%RPL_DIR%\build" rmdir /s /q "%RPL_DIR%\build"

powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\RPL Studio.lnk'); $s.TargetPath = '%RPL_DIR%\rpl.exe'; $s.WorkingDirectory = '%RPL_DIR%'; $s.IconLocation = '%RPL_DIR%\rpl.ico'; $s.Save()"

timeout /t 2 /nobreak >nul
powershell -NoProfile -Command "for ($i=1; $i -le 10; $i++) { try { Compress-Archive -Path '%RPL_DIR%\rpl.exe','%RPL_DIR%\library.txt','%RPL_DIR%\easy3d.rpl','%RPL_DIR%\hello.rpl','%RPL_DIR%\game2d.rpl','%RPL_DIR%\minecraft.rpl','%RPL_DIR%\textures','%RPL_DIR%\README.txt' -DestinationPath '%RPL_DIR%\RPL_Release.zip' -Force -ErrorAction Stop; break } catch { Write-Host 'Waiting for Antivirus...'; Start-Sleep -Seconds 2 } }"

echo.
echo ==================================================
echo   RPL v5.0 READY! Opening easy3d.rpl now...
echo ==================================================

start "" "%RPL_DIR%\rpl.exe"
explorer "%RPL_DIR%"
pause
exit /b 0

# ===BEGIN_RPL_PY===
import os
import sys
import ctypes
import traceback

os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "1"

if getattr(sys, "frozen", False):
    APP_DIR = os.path.dirname(sys.executable)
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))

CRASH_LOG_PATH = os.path.join(APP_DIR, "rpl_error.log")


def show_fatal_error(err_msg):
    try:
        with open(CRASH_LOG_PATH, "w", encoding="utf-8") as f:
            f.write(err_msg)
    except Exception:
        pass
    try:
        ctypes.windll.user32.MessageBoxW(0, err_msg, "RPL Studio Error", 0x10)
    except Exception:
        print(err_msg)


try:
    import re
    import time
    import math as py_math
    import struct
    import shutil
    import random
    import threading
    import subprocess
    import tkinter as tk
    from tkinter import filedialog, messagebox, simpledialog
    import customtkinter as ctk
except Exception:
    show_fatal_error("Startup import failed:\n\n" + traceback.format_exc())
    sys.exit(1)

try:
    import winsound
except ImportError:
    winsound = None

VERSION = "5.0"

LIB_PATH = os.path.join(APP_DIR, "library.txt")
LIB_BACKUP_PATH = os.path.join(APP_DIR, "library.txt.bak")
EASY3D_PATH = os.path.join(APP_DIR, "easy3d.rpl")
HELLO_PATH = os.path.join(APP_DIR, "hello.rpl")
GAME2D_PATH = os.path.join(APP_DIR, "game2d.rpl")
MINECRAFT_PATH = os.path.join(APP_DIR, "minecraft.rpl")
TEX_DIR = os.path.join(APP_DIR, "textures")
README_PATH = os.path.join(APP_DIR, "README.txt")
ICON_PATH = os.path.join(APP_DIR, "rpl.ico")
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

DEFAULT_EASY3D = """// easy3d.rpl - Build 3D worlds with simple coordinates & .png files!
// In-Game Controls:
//   WASD = Walk | Space = Jump | F = Fly Mode | G = Toggle 0,0,0 Axes
//   Left Click = Break | Right Click = Place | 1-9 = Switch Block | ESC = Unlock Mouse

3d title "RPL Easy 3D World"
3d sky "day"
3d grid on

// 1. Make a floor from (-6, 0, -6) to (6, 0, 6)
fill 3d grass.png from -6 0 -6 to 6 0 6

// 2. Add single blocks using exact X Y Z coordinates!
add 3d block dirt.png at 0 1 0
add 3d block brick.png at 2 1 0
add 3d block brick.png at 2 2 0
add 3d block diamond.png at 2 3 0
add 3d block gold.png at -2 1 2
add 3d block water.png at -3 0 -3

// 3. Mix with normal Python loops for stairs & towers!
for i in range(5):
    add 3d block stone.png at i i + 1 4

// 4. Set player start position & launch!
spawn at 0 4 -4
start 3d
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

hello
beep
"""

DEFAULT_GAME2D = """// game2d.rpl - Build ANY 2D Game using .png files!
use game
use math

game.start(900, 600, "RPL 2D Game (.png Textures)", fps=60)

px = 420
py = 280
score = 0
gem_x = math.rand(80, 820)
gem_y = math.rand(80, 420)

def update(dt):
    global px, py, score, gem_x, gem_y
    speed = 340 * dt

    if game.key("w") or game.key("up"):
        py -= speed
    if game.key("s") or game.key("down"):
        py += speed
    if game.key("a") or game.key("left"):
        px -= speed
    if game.key("d") or game.key("right"):
        px += speed

    if game.collide(px, py, 54, 54, gem_x, gem_y, 44, 44):
        score += 1
        gem_x = math.rand(60, 820)
        gem_y = math.rand(60, 420)
        go "Collected Diamond! Score: " + str(score)

    game.clear(18, 26, 48)
    game.image("brick.png", 40, 500, 820, 48)
    game.image("diamond.png", gem_x, gem_y, 44, 44)
    game.image("player.png", px, py, 54, 54)
    game.text("Score: " + str(score) + "  |  Move: WASD / Arrows", 20, 18, 22, (255, 255, 255))

game.loop(update)
"""

DEFAULT_MINECRAFT = """// minecraft.rpl - Full Procedural 3D Fan-Made Minecraft!
use voxel3d
use math

3d title "RPL Craft (Fan-Made Minecraft)"
3d sky "day"
3d grid off

for x in range(-9, 10):
    for z in range(-9, 10):
        h = int(2 + math.sin(x * 0.45) * 1.4 + math.cos(z * 0.45) * 1.4)
        for y in range(0, h + 1):
            if y == h:
                add 3d block grass.png at x y z
            elif y >= h - 1:
                add 3d block dirt.png at x y z
            else:
                add 3d block stone.png at x y z

        if (x == 3 and z == 3) or (x == -4 and z == 2) or (x == 2 and z == -5):
            for ty in range(1, 4):
                add 3d block wood.png at x h + ty z
            fill 3d leaves.png from x - 1 h + 4 z - 1 to x + 1 h + 4 z + 1
            add 3d block leaves.png at x h + 5 z

fill 3d brick.png from 0 4 5 to 0 6 5
add 3d block diamond.png at 0 7 5
add 3d block gold.png at 1 4 5

spawn at 0 7 0
start 3d
"""

DEFAULT_README = """RPL v5.0 (Ridwaan Programming Language)
=======================================
1. Double-click rpl.exe to launch RPL Studio.
2. Put any .png files in textures/ (or type full file paths!).
3. Easy 3D Commands:
   add 3d block dirt.png at 0 0 0
   fill 3d grass.png from -6 0 -6 to 6 0 6
   remove 3d block at 0 0 0
   spawn at 0 4 -4
   start 3d
4. Press F in 3D mode to Fly, and G to toggle 0,0,0 Coordinate Axes!
"""


def resolve_asset_path(path):
    p = str(path).strip()
    candidates = [
        p,
        os.path.join(APP_DIR, p),
        os.path.join(TEX_DIR, p),
        os.path.join(TEX_DIR, os.path.basename(p)),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return p


def generate_sample_textures():
    os.makedirs(TEX_DIR, exist_ok=True)
    try:
        from PIL import Image, ImageDraw
    except Exception:
        return

    def save_noise_tex(name, c1, c2, pattern="noise"):
        path = os.path.join(TEX_DIR, name)
        if os.path.exists(path):
            return
        img = Image.new("RGBA", (16, 16), c1 + (255,))
        px = img.load()
        rng = random.Random(name)
        for y in range(16):
            for x in range(16):
                if pattern == "brick":
                    if y in (0, 7, 15) or (y < 7 and x in (0, 8)) or (y > 7 and x in (4, 12)):
                        px[x, y] = c2 + (255,)
                    elif rng.random() < 0.28:
                        px[x, y] = (min(255, c1[0] + 16), c1[1], c1[2], 255)
                elif pattern == "wood":
                    px[x, y] = (c2 if x % 4 == 0 else c1) + (255,)
                elif pattern == "gem":
                    if 4 <= x <= 11 and 4 <= y <= 11:
                        px[x, y] = c2 + (255,)
                    elif rng.random() < 0.35:
                        px[x, y] = (145, 149, 155, 255)
                elif pattern == "water":
                    if (x + y) % 5 == 0:
                        px[x, y] = c2 + (255,)
                else:
                    if rng.random() < 0.38:
                        px[x, y] = c2 + (255,)
        img.save(path)

    save_noise_tex("grass.png", (94, 186, 68), (68, 146, 48))
    save_noise_tex("dirt.png", (134, 96, 67), (104, 72, 48))
    save_noise_tex("stone.png", (130, 134, 140), (102, 106, 114))
    save_noise_tex("wood.png", (150, 108, 62), (108, 74, 38), "wood")
    save_noise_tex("leaves.png", (52, 142, 58), (34, 100, 40))
    save_noise_tex("brick.png", (176, 76, 60), (210, 204, 194), "brick")
    save_noise_tex("diamond.png", (126, 130, 136), (64, 232, 240), "gem")
    save_noise_tex("gold.png", (126, 130, 136), (248, 210, 56), "gem")
    save_noise_tex("sand.png", (226, 206, 144), (206, 184, 122))
    save_noise_tex("water.png", (52, 132, 236), (88, 166, 250), "water")

    player_path = os.path.join(TEX_DIR, "player.png")
    if not os.path.exists(player_path):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([4, 2, 27, 29], radius=6, fill=(56, 189, 248, 255), outline=(255, 255, 255, 255), width=2)
        d.rectangle([9, 9, 13, 14], fill=(15, 23, 42, 255))
        d.rectangle([19, 9, 23, 14], fill=(15, 23, 42, 255))
        d.rectangle([10, 20, 22, 23], fill=(52, 211, 153, 255))
        img.save(player_path)


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
    colors = {"R": (248, 189, 56, 255), "P": (255, 255, 255, 255), "L": (153, 211, 52, 255)}

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


def ensure_files(overwrite_templates=False):
    defaults = [
        (LIB_PATH, DEFAULT_LIB, False),
        (EASY3D_PATH, DEFAULT_EASY3D, overwrite_templates),
        (HELLO_PATH, DEFAULT_HELLO, overwrite_templates),
        (GAME2D_PATH, DEFAULT_GAME2D, overwrite_templates),
        (MINECRAFT_PATH, DEFAULT_MINECRAFT, overwrite_templates),
        (README_PATH, DEFAULT_README, True),
    ]
    for path, content, force in defaults:
        if force or not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
    if not os.path.exists(ICON_PATH):
        generate_rpl_ico(ICON_PATH)
    generate_sample_textures()


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


def parse_coords_list(coord_str):
    s = coord_str.strip()
    parts, cur, depth, in_q = [], [], 0, None
    for i, ch in enumerate(s):
        if ch in ('"', "'") and (i == 0 or s[i - 1] != "\\"):
            in_q = None if in_q == ch else (in_q or ch)
        elif in_q is None:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth = max(0, depth - 1)
            elif ch == "," and depth == 0:
                parts.append("".join(cur).strip())
                cur = []
                continue
        cur.append(ch)
    parts.append("".join(cur).strip())
    if len(parts) > 1:
        return parts

    collapsed = s
    for _ in range(4):
        new_c = re.sub(r"\s+([+\-*/%])\s+", r"\1", collapsed)
        if new_c == collapsed:
            break
        collapsed = new_c

    parts, cur, depth, in_q = [], [], 0, None
    for i, ch in enumerate(collapsed):
        if ch in ('"', "'") and (i == 0 or collapsed[i - 1] != "\\"):
            in_q = None if in_q == ch else (in_q or ch)
        elif in_q is None:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth = max(0, depth - 1)
            elif ch.isspace() and depth == 0:
                if cur:
                    parts.append("".join(cur))
                    cur = []
                continue
        cur.append(ch)
    if cur:
        parts.append("".join(cur))
    return parts


def tex_expr(raw_tex):
    t = raw_tex.strip()
    if (t.startswith('"') and t.endswith('"')) or (t.startswith("'") and t.endswith("'")):
        return t
    if "." in t or "/" in t or "\\" in t:
        return repr(t)
    return t


def preprocess_rpl(code_text, dictionary):
    sorted_keys = sorted(dictionary.keys(), key=len, reverse=True)
    out_lines = []
    bracket_depth = 0

    for raw in code_text.splitlines():
        line = replace_slash_comments(raw)
        stripped = line.strip()
        indent = line[:len(line) - len(line.lstrip(" \t"))]

        if bracket_depth == 0 and stripped and not stripped.startswith("#"):
            code_part = stripped
            in_q = None
            for idx_c, c in enumerate(stripped):
                if c in ('"', "'") and (idx_c == 0 or stripped[idx_c - 1] != "\\"):
                    in_q = None if in_q == c else (in_q or c)
                elif in_q is None and c == "#":
                    code_part = stripped[:idx_c].strip()
                    break

            # --- Easy 3D English Commands ---
            m_add3d = re.match(r"^add\s+3d\s+block\s+(.+?)\s+at\s+(.+)$", code_part)
            m_fill3d = re.match(r"^fill\s+3d\s+(.+?)\s+from\s+(.+?)\s+to\s+(.+)$", code_part)
            m_rem3d = re.match(r"^remove\s+3d\s+block\s+at\s+(.+)$", code_part)
            m_spawn = re.match(r"^spawn\s+at\s+(.+)$", code_part)
            m_3dtitle = re.match(r"^3d\s+title\s+(.+)$", code_part)
            m_3dsky = re.match(r"^3d\s+sky\s+(.+)$", code_part)
            m_3dgrid = re.match(r"^3d\s+grid\s+(on|off|true|false)$", code_part, re.I)
            m_3dspeed = re.match(r"^3d\s+speed\s+(.+)$", code_part)
            m_3djump = re.match(r"^3d\s+jump\s+(.+)$", code_part)

            if m_add3d:
                tx = tex_expr(m_add3d.group(1))
                c = parse_coords_list(m_add3d.group(2))
                if len(c) != 3:
                    raise SyntaxError(f"Expected 3 coordinates (X Y Z) in: {code_part}")
                line = f"{indent}__rpl_3d_block__({tx}, {c[0]}, {c[1]}, {c[2]})"
            elif m_fill3d:
                tx = tex_expr(m_fill3d.group(1))
                c1 = parse_coords_list(m_fill3d.group(2))
                c2 = parse_coords_list(m_fill3d.group(3))
                if len(c1) != 3 or len(c2) != 3:
                    raise SyntaxError(f"Expected 3 coordinates for 'from' and 'to' in: {code_part}")
                line = f"{indent}__rpl_3d_fill__({tx}, {c1[0]}, {c1[1]}, {c1[2]}, {c2[0]}, {c2[1]}, {c2[2]})"
            elif m_rem3d:
                c = parse_coords_list(m_rem3d.group(1))
                if len(c) != 3:
                    raise SyntaxError(f"Expected 3 coordinates (X Y Z) in: {code_part}")
                line = f"{indent}__rpl_3d_remove__({c[0]}, {c[1]}, {c[2]})"
            elif m_spawn:
                c = parse_coords_list(m_spawn.group(1))
                if len(c) != 3:
                    raise SyntaxError(f"Expected 3 coordinates (X Y Z) in: {code_part}")
                line = f"{indent}__rpl_3d_spawn__({c[0]}, {c[1]}, {c[2]})"
            elif m_3dtitle:
                line = f"{indent}__rpl_3d_title__({m_3dtitle.group(1).strip()})"
            elif m_3dsky:
                arg = m_3dsky.group(1).strip()
                c = parse_coords_list(arg)
                if len(c) == 3:
                    line = f"{indent}__rpl_3d_sky__(({c[0]}, {c[1]}, {c[2]}))"
                else:
                    line = f"{indent}__rpl_3d_sky__({tex_expr(arg)})"
            elif m_3dgrid:
                val = "True" if m_3dgrid.group(1).lower() in ("on", "true") else "False"
                line = f"{indent}__rpl_3d_grid__({val})"
            elif m_3dspeed:
                line = f"{indent}__rpl_3d_prop__('speed', {m_3dspeed.group(1).strip()})"
            elif m_3djump:
                line = f"{indent}__rpl_3d_prop__('jump', {m_3djump.group(1).strip()})"
            elif code_part in ("start 3d", "run 3d"):
                line = f"{indent}__rpl_3d_start__()"
            elif code_part.startswith("use ") or code_part.startswith("import "):
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


class FileLib:
    def save(self, name, content):
        path = os.path.join(APP_DIR, os.path.basename(str(name)))
        with open(path, "w", encoding="utf-8") as f:
            f.write(str(content))
    def load(self, name):
        path = resolve_asset_path(name)
        if not os.path.exists(path):
            return ""
        with open(path, "r", encoding="utf-8") as f:
            return f.read()


class Game2DLib:
    def __init__(self):
        import pygame
        self.pg = pygame
        self.screen = None
        self.clock = None
        self.running = False
        self.fonts = {}
        self.img_cache = {}
        self.sound_cache = {}
        self.width = 900
        self.height = 600

    def start(self, width=900, height=600, title="RPL Game", fps=60):
        self.width, self.height = int(width), int(height)
        self.pg.init()
        try:
            self.pg.mixer.init()
        except Exception:
            pass
        self.screen = self.pg.display.set_mode((self.width, self.height))
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

    def _load_img(self, path, w=None, h=None, flip_x=False):
        full = resolve_asset_path(path)
        key = (full, w, h, flip_x)
        if key not in self.img_cache:
            surf = self.pg.image.load(full).convert_alpha()
            if w is not None and h is not None:
                surf = self.pg.transform.smoothscale(surf, (int(w), int(h)))
            if flip_x:
                surf = self.pg.transform.flip(surf, True, False)
            self.img_cache[key] = surf
        return self.img_cache[key]

    def bg(self, path):
        if self.screen:
            self.screen.blit(self._load_img(path, self.width, self.height), (0, 0))

    def image(self, path, x, y, w=None, h=None, flip_x=False):
        if self.screen:
            self.screen.blit(self._load_img(path, w, h, flip_x), (int(x), int(y)))

    def sound(self, path):
        try:
            full = resolve_asset_path(path)
            if full not in self.sound_cache:
                self.sound_cache[full] = self.pg.mixer.Sound(full)
            self.sound_cache[full].play()
        except Exception:
            pass

    def collide(self, x1, y1, w1, h1, x2, y2, w2, h2):
        return (x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2)

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
            self.screen.blit(self.fonts[s].render(str(msg), True, color), (int(x), int(y)))

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
        "grass":   ((94, 186, 68), (134, 96, 67)),
        "dirt":    ((134, 96, 67), (120, 84, 58)),
        "stone":   ((132, 136, 142), (118, 122, 128)),
        "wood":    ((166, 126, 76), (118, 82, 46)),
        "leaves":  ((54, 142, 58), (44, 120, 48)),
        "diamond": ((68, 228, 236), (52, 200, 212)),
        "gold":    ((248, 210, 62), (222, 182, 44)),
        "brick":   ((178, 78, 62), (156, 66, 52)),
        "sand":    ((226, 206, 144), (206, 184, 122)),
        "water":   ((56, 136, 236), (48, 120, 214)),
    }

    def __init__(self, title="RPL 3D Engine", width=1120, height=700):
        self.title = str(title)
        self.width = int(width)
        self.height = int(height)
        self.blocks = {}
        self.custom_textures = {}
        self.hotbar_order = ["grass", "dirt", "stone", "wood", "leaves", "brick", "gold", "diamond", "water"]
        self.spawn = [0.5, 6.0, 0.5]
        self.sky_color = (128, 194, 255)
        self.show_grid = True
        self.move_speed = 4.8
        self.jump_power = 8.4
        self.on_update_cb = None
        self.on_break_cb = None
        self.on_place_cb = None

    def set_sky(self, sky_val):
        if isinstance(sky_val, (tuple, list)) and len(sky_val) == 3:
            self.sky_color = (int(sky_val[0]), int(sky_val[1]), int(sky_val[2]))
        else:
            s = str(sky_val).lower()
            presets = {"day": (128, 194, 255), "night": (14, 20, 44), "sunset": (244, 138, 96), "space": (8, 10, 22)}
            self.sky_color = presets.get(s, (128, 194, 255))

    def set_texture(self, block_name, png_path):
        bname = str(block_name).lower()
        self.custom_textures[bname] = resolve_asset_path(png_path)
        if bname not in self.hotbar_order:
            self.hotbar_order.insert(0, bname)
            self.hotbar_order = self.hotbar_order[:9]
        return bname

    def add_by_path_or_name(self, tex_or_name, x, y, z):
        raw = str(tex_or_name).strip()
        low = raw.lower()
        if low == "air":
            self.remove_block(x, y, z)
            return
        if low.endswith((".png", ".jpg", ".jpeg", ".bmp")) or "/" in raw or "\\" in raw:
            bname = os.path.splitext(os.path.basename(raw))[0].lower()
            self.set_texture(bname, raw)
            self.set_block(x, y, z, bname)
        else:
            self.set_block(x, y, z, low)

    def set_block(self, x, y, z, btype="grass"):
        btype = str(btype).lower()
        if btype == "air":
            self.blocks.pop((int(x), int(y), int(z)), None)
        else:
            self.blocks[(int(x), int(y), int(z))] = btype

    def fill(self, tex_or_name, x1, y1, z1, x2, y2, z2):
        xa, xb = min(int(x1), int(x2)), max(int(x1), int(x2))
        ya, yb = min(int(y1), int(y2)), max(int(y1), int(y2))
        za, zb = min(int(z1), int(z2)), max(int(z1), int(z2))
        for bx in range(xa, xb + 1):
            for by in range(ya, yb + 1):
                for bz in range(za, zb + 1):
                    self.add_by_path_or_name(tex_or_name, bx, by, bz)

    def get_block(self, x, y, z): return self.blocks.get((int(x), int(y), int(z)), "air")
    def remove_block(self, x, y, z): return self.blocks.pop((int(x), int(y), int(z)), None)
    def set_spawn(self, x, y, z): self.spawn = [float(x) + 0.5, float(y), float(z) + 0.5]
    def on_update(self, fn): self.on_update_cb = fn
    def on_break(self, fn): self.on_break_cb = fn
    def on_place(self, fn): self.on_place_cb = fn

    def _clip_near(self, poly, near=0.15):
        out = []
        n = len(poly)
        for i in range(n):
            a, b = poly[i], poly[(i + 1) % n]
            a_in, b_in = a[2] >= near, b[2] >= near
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
        r, h = 0.28, 1.75
        for bx in range(py_math.floor(px - r), py_math.floor(px + r) + 1):
            for by in range(py_math.floor(py), py_math.floor(py + h) + 1):
                for bz in range(py_math.floor(pz - r), py_math.floor(pz + r) + 1):
                    if (bx, by, bz) in self.blocks:
                        return True
        return False

    def _raycast(self, cx, cy, cz, lx, ly, lz, max_dist=6.0):
        prev = None
        t = 0.2
        while t <= max_dist:
            cell = (py_math.floor(cx + lx * t), py_math.floor(cy + ly * t), py_math.floor(cz + lz * t))
            if cell in self.blocks:
                return cell, prev
            prev = cell
            t += 0.05
        return None, None

    def _prepare_textures(self, pygame):
        tex_data = {}
        for name in set(list(self.PALETTE.keys()) + list(self.custom_textures.keys()) + self.hotbar_order + list(self.blocks.values())):
            path = self.custom_textures.get(name) or resolve_asset_path(f"{name}.png")
            if path and os.path.exists(path):
                try:
                    raw_surf = pygame.image.load(path).convert_alpha()
                    thumb = pygame.transform.smoothscale(raw_surf, (28, 28))
                    g4 = pygame.transform.smoothscale(raw_surf, (4, 4))
                    grid4 = [[g4.get_at((gx, gy))[:3] for gx in range(4)] for gy in range(4)]
                    g2 = pygame.transform.smoothscale(raw_surf, (2, 2))
                    grid2 = [[g2.get_at((gx, gy))[:3] for gx in range(2)] for gy in range(2)]
                    avg = pygame.transform.smoothscale(raw_surf, (1, 1)).get_at((0, 0))[:3]
                    tex_data[name] = {"thumb": thumb, "grid4": grid4, "grid2": grid2, "avg": avg}
                    continue
                except Exception:
                    pass
            top_c, _ = self.PALETTE.get(name, ((180, 180, 180), (150, 150, 150)))
            tex_data[name] = {"thumb": None, "grid4": None, "grid2": None, "avg": top_c}
        return tex_data

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

        tex_data = self._prepare_textures(pygame)
        clock = pygame.time.Clock()
        font = pygame.font.SysFont("consolas", 14, bold=True)
        font_sm = pygame.font.SysFont("consolas", 12, bold=True)

        px, py, pz = list(self.spawn)
        vy, on_ground, fly_mode, yaw, pitch, selected_idx = 0.0, False, False, 0.0, -0.15, 0
        mouse_locked = True
        pygame.mouse.set_visible(False)
        pygame.event.set_grab(True)
        pygame.mouse.get_rel()

        half_w, half_h, fov = self.width / 2.0, self.height / 2.0, self.height * 0.85
        FACES = [
            ((0, 1, 0),  ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)), 1.00, True),
            ((0, -1, 0), ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)), 0.55, False),
            ((1, 0, 0),  ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)), 0.82, False),
            ((-1, 0, 0), ((0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)), 0.82, False),
            ((0, 0, 1),  ((1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)), 0.70, False),
            ((0, 0, -1), ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)), 0.70, False),
        ]
        sky = self.sky_color
        running = True

        def lerp3(a, b, t):
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

        def proj_3d_line(p1, p2, col, width_px=2):
            pts = []
            for wx, wy, wz in (p1, p2):
                dx, dy, dz = wx - cam_x, wy - cam_y, wz - cam_z
                x1 = dx * cos_y - dz * sin_y
                z1 = dx * sin_y + dz * cos_y
                y2 = dy * cos_p - z1 * sin_p
                z2 = dy * sin_p + z1 * cos_p
                pts.append((x1, y2, z2))
            a, b = pts
            if a[2] < 0.2 and b[2] < 0.2:
                return
            if a[2] < 0.2:
                t = (0.2 - a[2]) / (b[2] - a[2])
                a = lerp3(a, b, t)
            elif b[2] < 0.2:
                t = (0.2 - b[2]) / (a[2] - b[2])
                b = lerp3(b, a, t)
            sa = (half_w + (a[0] / a[2]) * fov, half_h - (a[1] / a[2]) * fov)
            sb = (half_w + (b[0] / b[2]) * fov, half_h - (b[1] / b[2]) * fov)
            pygame.draw.line(screen, col, sa, sb, width_px)

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
                    elif ev.key == pygame.K_f:
                        fly_mode = not fly_mode
                        vy = 0.0
                    elif ev.key == pygame.K_g:
                        self.show_grid = not self.show_grid
                    elif pygame.K_1 <= ev.key <= pygame.K_9:
                        idx = ev.key - pygame.K_1
                        if idx < len(self.hotbar_order):
                            selected_idx = idx
                elif ev.type == pygame.MOUSEWHEEL:
                    selected_idx = (selected_idx - ev.y) % len(self.hotbar_order)
                elif ev.type == pygame.MOUSEBUTTONDOWN:
                    if not mouse_locked:
                        mouse_locked = True
                        pygame.mouse.set_visible(False)
                        pygame.event.set_grab(True)
                        pygame.mouse.get_rel()
                    else:
                        lx = py_math.sin(yaw) * py_math.cos(pitch)
                        ly = py_math.sin(pitch)
                        lz = py_math.cos(yaw) * py_math.cos(pitch)
                        hit, prev = self._raycast(px, py + 1.55, pz, lx, ly, lz)
                        if ev.button == 1 and hit:
                            btype = self.blocks.pop(hit, None)
                            if btype and self.on_break_cb:
                                self.on_break_cb(hit[0], hit[1], hit[2], btype)
                        elif ev.button == 3 and prev:
                            btype = self.hotbar_order[selected_idx]
                            self.blocks[prev] = btype
                            if not fly_mode and self._collides(px, py, pz):
                                self.blocks.pop(prev, None)
                            elif self.on_place_cb:
                                self.on_place_cb(prev[0], prev[1], prev[2], btype)

            if mouse_locked:
                mx, my = pygame.mouse.get_rel()
                yaw += mx * 0.0028
                pitch = max(-1.45, min(1.45, pitch - my * 0.0028))

            keys = pygame.key.get_pressed()
            speed = self.move_speed * (1.6 if keys[pygame.K_LCTRL] else 1.0)
            fx, fz = py_math.sin(yaw), py_math.cos(yaw)
            rx, rz = py_math.cos(yaw), -py_math.sin(yaw)
            mv_x = mv_z = 0.0
            if keys[pygame.K_w]: mv_x += fx; mv_z += fz
            if keys[pygame.K_s]: mv_x -= fx; mv_z -= fz
            if keys[pygame.K_d]: mv_x += rx; mv_z += rz
            if keys[pygame.K_a]: mv_x -= rx; mv_z -= rz

            mag = (mv_x * mv_x + mv_z * mv_z) ** 0.5
            if mag > 0:
                mv_x, mv_z = (mv_x / mag) * speed * dt, (mv_z / mag) * speed * dt
                if fly_mode or not self._collides(px + mv_x, py, pz): px += mv_x
                if fly_mode or not self._collides(px, py, pz + mv_z): pz += mv_z

            if fly_mode:
                if keys[pygame.K_SPACE]: py += speed * dt
                if keys[pygame.K_LSHIFT]: py -= speed * dt
            else:
                if on_ground and keys[pygame.K_SPACE]:
                    vy, on_ground = self.jump_power, False
                vy -= 22.0 * dt
                if not self._collides(px, py + vy * dt, pz):
                    py += vy * dt
                    on_ground = False
                else:
                    if vy < 0: on_ground = True
                    vy = 0.0
                if py < -15:
                    px, py, pz = list(self.spawn)
                    vy = 0.0

            if self.on_update_cb:
                self.on_update_cb(self, dt)

            cam_x, cam_y, cam_z = px, py + 1.55, pz
            sin_y, cos_y = py_math.sin(yaw), py_math.cos(yaw)
            sin_p, cos_p = py_math.sin(pitch), py_math.cos(pitch)
            lx, ly, lz = sin_y * cos_p, sin_p, cos_y * cos_p
            target_hit, _ = self._raycast(cam_x, cam_y, cam_z, lx, ly, lz)

            screen.fill(sky)
            render_list = []

            for (bx, by, bz), btype in self.blocks.items():
                dx_c, dy_c, dz_c = (bx + 0.5) - cam_x, (by + 0.5) - cam_y, (bz + 0.5) - cam_z
                dist2 = dx_c * dx_c + dy_c * dy_c + dz_c * dz_c
                if dist2 > 110.0: continue
                if dist2 > 2.5 and (dx_c * lx + dy_c * ly + dz_c * lz) < -0.35 * (dist2 ** 0.5): continue

                info = tex_data.get(btype, {"grid4": None, "grid2": None, "avg": (180, 180, 180)})
                is_target = (bx, by, bz) == target_hit

                for (nx, ny, nz), corners, shade, is_top in FACES:
                    if (bx + nx, by + ny, bz + nz) in self.blocks: continue
                    fcx, fcy, fcz = bx + 0.5 + nx * 0.5, by + 0.5 + ny * 0.5, bz + 0.5 + nz * 0.5
                    if (cam_x - fcx) * nx + (cam_y - fcy) * ny + (cam_z - fcz) * nz <= 0: continue

                    cam_poly = []
                    for ox, oy, oz in corners:
                        wx, wy, wz = (bx + ox) - cam_x, (by + oy) - cam_y, (bz + oz) - cam_z
                        x1 = wx * cos_y - wz * sin_y
                        z1 = wx * sin_y + wz * cos_y
                        y2 = wy * cos_p - z1 * sin_p
                        z2 = wy * sin_p + z1 * cos_p
                        cam_poly.append((x1, y2, z2))

                    fdist2 = (fcx - cam_x) ** 2 + (fcy - cam_y) ** 2 + (fcz - cam_z) ** 2
                    fog = min(0.6, max(0.0, (dist2 - 42.0) / 90.0))

                    # 4x4 .png texture up close (<3.5 blocks), 2x2 medium (<6 blocks), solid far
                    grid = None
                    if dist2 < 12.25 and info["grid4"] and all(v[2] >= 0.25 for v in cam_poly):
                        grid = info["grid4"]
                    elif dist2 < 36.0 and info["grid2"] and all(v[2] >= 0.25 for v in cam_poly):
                        grid = info["grid2"]

                    if grid:
                        gn = len(grid)
                        p00, p01, p11, p10 = cam_poly
                        proj = []
                        for r_i in range(gn + 1):
                            rv = r_i / float(gn)
                            row_pts = []
                            top_e = lerp3(p00, p01, rv)
                            bot_e = lerp3(p10, p11, rv)
                            for c_i in range(gn + 1):
                                pt = lerp3(top_e, bot_e, c_i / float(gn))
                                row_pts.append((half_w + (pt[0] / pt[2]) * fov, half_h - (pt[1] / pt[2]) * fov))
                            proj.append(row_pts)
                        sub_polys = []
                        for r_i in range(gn):
                            for c_i in range(gn):
                                tc = grid[r_i][c_i]
                                cr = int((tc[0] * shade) * (1 - fog) + sky[0] * fog)
                                cg = int((tc[1] * shade) * (1 - fog) + sky[1] * fog)
                                cb = int((tc[2] * shade) * (1 - fog) + sky[2] * fog)
                                quad = [proj[r_i][c_i], proj[r_i][c_i + 1], proj[r_i + 1][c_i + 1], proj[r_i + 1][c_i]]
                                sub_polys.append((quad, (cr, cg, cb)))
                        outer = [proj[0][0], proj[0][gn], proj[gn][gn], proj[gn][0]]
                        render_list.append((fdist2, True, sub_polys, outer, is_target))
                    else:
                        clipped = self._clip_near(cam_poly, 0.15)
                        if len(clipped) < 3: continue
                        pts2d = [(half_w + (vx / vz) * fov, half_h - (vy_ / vz) * fov) for vx, vy_, vz in clipped]
                        base = info["avg"]
                        if btype == "grass" and not is_top and "grass" not in self.custom_textures:
                            base = self.PALETTE["grass"][1]
                        cr = int((base[0] * shade) * (1 - fog) + sky[0] * fog)
                        cg = int((base[1] * shade) * (1 - fog) + sky[1] * fog)
                        cb = int((base[2] * shade) * (1 - fog) + sky[2] * fog)
                        render_list.append((fdist2, False, pts2d, (cr, cg, cb), is_target))

            render_list.sort(key=lambda item: item[0], reverse=True)
            for item in render_list:
                if item[1]:
                    _, _, sub_polys, outer, is_target = item
                    for quad, col in sub_polys:
                        pygame.draw.polygon(screen, col, quad)
                    pygame.draw.polygon(screen, (255, 255, 255) if is_target else (30, 35, 45), outer, 2 if is_target else 1)
                else:
                    _, _, pts2d, col, is_target = item
                    pygame.draw.polygon(screen, col, pts2d)
                    pygame.draw.polygon(screen, (255, 255, 255) if is_target else (30, 35, 45), pts2d, 2 if is_target else 1)

            # Coordinate Axes Helper at (0, 0, 0)
            if self.show_grid:
                proj_3d_line((0, 0.05, 0), (5, 0.05, 0), (244, 63, 94), 3)    # +X Red
                proj_3d_line((0, 0.05, 0), (0, 5, 0), (52, 211, 153), 3)    # +Y Green
                proj_3d_line((0, 0.05, 0), (0, 0.05, 5), (56, 189, 248), 3) # +Z Blue

            # Crosshair
            pygame.draw.line(screen, (255, 255, 255), (half_w - 8, half_h), (half_w + 8, half_h), 2)
            pygame.draw.line(screen, (255, 255, 255), (half_w, half_h - 8), (half_w, half_h + 8), 2)

            # Coordinate & Status HUD
            look_str = f"Looking at: {target_hit} [{self.blocks[target_hit]}]" if target_hit else "Looking at: air"
            hud = f"You: ({int(px)}, {int(py)}, {int(pz)}) | {look_str} | {'FLY' if fly_mode else 'WALK'} | [F] Fly [G] Grid [ESC] Mouse"
            hud_surf = font.render(hud, True, (255, 255, 255))
            pygame.draw.rect(screen, (15, 23, 42), (8, 8, hud_surf.get_width() + 16, 28), border_radius=6)
            screen.blit(hud_surf, (16, 13))

            # Hotbar
            slot_w, slot_h, gap = 52, 52, 6
            total_w = len(self.hotbar_order) * (slot_w + gap) - gap
            start_x = (self.width - total_w) // 2
            bar_y = self.height - 68
            for idx, bname in enumerate(self.hotbar_order):
                sx = start_x + idx * (slot_w + gap)
                is_sel = idx == selected_idx
                pygame.draw.rect(screen, (30, 41, 59), (sx, bar_y, slot_w, slot_h), border_radius=6)
                pygame.draw.rect(screen, (56, 189, 248) if is_sel else (71, 85, 105), (sx, bar_y, slot_w, slot_h), 3 if is_sel else 1, border_radius=6)
                tinfo = tex_data.get(bname, {})
                if tinfo.get("thumb"):
                    screen.blit(tinfo["thumb"], (sx + 12, bar_y + 8))
                else:
                    pygame.draw.rect(screen, tinfo.get("avg", (180, 180, 180)), (sx + 12, bar_y + 10, 28, 22), border_radius=3)
                screen.blit(font_sm.render(str(idx + 1), True, (255, 255, 255)), (sx + 4, bar_y + 2))
                screen.blit(font_sm.render(bname[:5], True, (226, 232, 240)), (sx + 6, bar_y + 36))

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


def run_rpl_code(code_text, lib_text, emit_fn):
    dictionary, _ = parse_library_content(lib_text)
    default_world = [None]

    def get_world():
        if default_world[0] is None:
            default_world[0] = Voxel3DWorld()
        return default_world[0]

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
        if lib_name == "math": env["math"] = MathLib()
        elif lib_name == "text": env["text"] = TextLib()
        elif lib_name == "time": env["time"] = TimeLib()
        elif lib_name == "file": env["file"] = FileLib()
        elif lib_name == "ui": env["ui"] = UILib(emit_fn)
        elif lib_name == "game": env["game"] = Game2DLib()
        elif lib_name == "voxel3d": env["voxel3d"] = Voxel3DLib()
        else:
            raise ImportError(f"Unknown RPL library '{lib_name}'. Check Library Base!")

    env["go"] = rpl_go
    env["__rpl_go_key__"] = rpl_go_key
    env["__rpl_cmd__"] = rpl_cmd
    env["__rpl_use__"] = rpl_use
    env["__rpl_3d_block__"] = lambda tex, x, y, z: get_world().add_by_path_or_name(tex, x, y, z)
    env["__rpl_3d_fill__"] = lambda tex, x1, y1, z1, x2, y2, z2: get_world().fill(tex, x1, y1, z1, x2, y2, z2)
    env["__rpl_3d_remove__"] = lambda x, y, z: get_world().remove_block(x, y, z)
    env["__rpl_3d_spawn__"] = lambda x, y, z: get_world().set_spawn(x, y, z)
    env["__rpl_3d_title__"] = lambda t: setattr(get_world(), "title", str(t))
    env["__rpl_3d_sky__"] = lambda s: get_world().set_sky(s)
    env["__rpl_3d_grid__"] = lambda g: setattr(get_world(), "show_grid", bool(g))
    env["__rpl_3d_prop__"] = lambda k, v: setattr(get_world(), "move_speed" if k == "speed" else "jump_power", float(v))
    env["__rpl_3d_start__"] = lambda: get_world().run()

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
        print(f"__RPL_{kind}__:{str(payload).replace(chr(10), chr(92) + 'n')}", flush=True)

    try:
        run_rpl_code(code_text, lib_text, emit)
        emit("DONE", "Done.")
    except Exception as e:
        emit("ERR", f"{type(e).__name__}: {e}")


class RPLStudioApp:
    def __init__(self, root):
        self.root = root
        self.root.title(f"RPL Studio v{VERSION} - Ridwaan Programming Language")
        self.root.geometry("1320x800")
        self.game_proc = None
        self.current_rpl_path = EASY3D_PATH
        self.pure_binary_var = tk.BooleanVar(value=True)

        ensure_files(overwrite_templates=False)
        self._apply_icon()
        self._build_ui()
        self.load_files()

        self.root.bind("<Control-s>", lambda e: self.save_files())
        self.root.after(250, self._apply_icon)
        self.root.after(300, self._show_window_foreground)
        self.root.after(550, self.check_downloads_update)

    def _apply_icon(self):
        ico = get_icon_path()
        if os.path.exists(ico):
            try:
                self.root.iconbitmap(ico)
            except Exception:
                pass

    def _show_window_foreground(self):
        try:
            self.root.deiconify()
            self.root.state("normal")
            self.root.lift()
            self.root.focus_force()
        except Exception:
            pass

    def _build_ui(self):
        top = ctk.CTkFrame(self.root, height=64, corner_radius=12, fg_color="#11182d")
        top.pack(fill="x", padx=14, pady=(12, 8))

        left_box = ctk.CTkFrame(top, fg_color="transparent")
        left_box.pack(side="left", padx=14, pady=8)
        ctk.CTkLabel(left_box, text=f"RPL STUDIO v{VERSION}", font=ctk.CTkFont("Segoe UI", 18, "bold"), text_color="#38bdf8").pack(anchor="w")
        ctk.CTkLabel(left_box, text="Easy 3D Coordinates + .png Textures + Full Python-Strength Coding", font=ctk.CTkFont("Segoe UI", 11), text_color="#94a3b8").pack(anchor="w")

        right_box = ctk.CTkFrame(top, fg_color="transparent")
        right_box.pack(side="right", padx=12, pady=10)

        self.file_switch = ctk.CTkOptionMenu(
            right_box, values=["easy3d.rpl", "minecraft.rpl", "game2d.rpl", "hello.rpl", "Open Other..."],
            command=self.on_file_menu, width=135, fg_color="#1e293b", button_color="#334155"
        )
        self.file_switch.pack(side="left", padx=3)

        ctk.CTkButton(right_box, text="+ New .rpl", command=self.new_rpl_file, width=82, fg_color="#334155", hover_color="#475569").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Library Base", command=self.open_library_base, width=100, fg_color="#2563eb", hover_color="#1d4ed8").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Textures", command=lambda: os.startfile(TEX_DIR), width=80, fg_color="#4338ca", hover_color="#3730a3").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Update .txt", command=self.manual_import_downloads, width=90, fg_color="#0f766e", hover_color="#0d9488").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Save", command=self.save_files, width=60, fg_color="#1e293b", hover_color="#334155").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Stop", command=self.stop_rpl, width=60, fg_color="#7f1d1d", hover_color="#991b1b").pack(side="left", padx=3)
        ctk.CTkButton(right_box, text="Run RPL", command=self.start_rpl, width=95, fg_color="#10b981", hover_color="#059669", text_color="#042f2e", font=ctk.CTkFont("Segoe UI", 13, "bold")).pack(side="left", padx=(5, 0))

        main = ctk.CTkFrame(self.root, fg_color="transparent")
        main.pack(fill="both", expand=True, padx=14, pady=(0, 14))
        main.grid_columnconfigure(0, weight=1)
        main.grid_columnconfigure(1, weight=2)
        main.grid_columnconfigure(2, weight=1)
        main.grid_rowconfigure(0, weight=1)

        c1 = ctk.CTkFrame(main, corner_radius=12, fg_color="#11182d")
        c1.grid(row=0, column=0, sticky="nsew", padx=(0, 6))
        c1_head = ctk.CTkFrame(c1, fg_color="#17203d", corner_radius=10)
        c1_head.pack(fill="x", padx=8, pady=(8, 4))
        ctk.CTkLabel(c1_head, text="library.txt (8-Bit Binary)", font=ctk.CTkFont("Segoe UI", 13, "bold")).pack(side="left", padx=10, pady=6)
        ctk.CTkButton(c1_head, text="Reload", width=60, height=24, command=self.reload_library_from_disk, fg_color="#273663").pack(side="right", padx=8)

        self.lib_text = ctk.CTkTextbox(c1, font=ctk.CTkFont("Consolas", 12), text_color="#fbbf24", fg_color="#080c18", corner_radius=10, wrap="word")
        self.lib_text.pack(fill="both", expand=True, padx=8, pady=4)
        self.lib_status = ctk.CTkLabel(c1, text="0 commands", font=ctk.CTkFont("Segoe UI", 11), text_color="#94a3b8")
        self.lib_status.pack(anchor="w", padx=12, pady=(0, 6))

        c2 = ctk.CTkFrame(main, corner_radius=12, fg_color="#11182d")
        c2.grid(row=0, column=1, sticky="nsew", padx=6)
        c2_head = ctk.CTkFrame(c2, fg_color="#17203d", corner_radius=10)
        c2_head.pack(fill="x", padx=8, pady=(8, 4))
        self.code_header = ctk.CTkLabel(c2_head, text="easy3d.rpl", font=ctk.CTkFont("Segoe UI", 13, "bold"))
        self.code_header.pack(side="left", padx=10, pady=6)

        self.code_text = ctk.CTkTextbox(c2, font=ctk.CTkFont("Consolas", 13), text_color="#e2e8f0", fg_color="#080c18", corner_radius=10, wrap="none")
        self.code_text.pack(fill="both", expand=True, padx=8, pady=4)

        quick_bar = ctk.CTkFrame(c2, fg_color="#17203d", corner_radius=8)
        quick_bar.pack(fill="x", padx=8, pady=(2, 8))
        snippets = [
            ("+ 3D Block", "add 3d block dirt.png at 0 1 0\n"),
            ("+ 3D Floor", "fill 3d grass.png from -5 0 -5 to 5 0 5\n"),
            ("+ Start 3D", "spawn at 0 4 -4\nstart 3d\n"),
            ("+ 2D Image", 'game.image("player.png", 100, 100, 48, 48)\n'),
            ("+ go", 'go "Hello!"\n'),
        ]
        for label, snip in snippets:
            ctk.CTkButton(quick_bar, text=label, width=78, height=26, font=ctk.CTkFont("Segoe UI", 11), fg_color="#25335c", hover_color="#33467d", command=lambda s=snip: self.insert_snippet(s)).pack(side="left", padx=3, pady=4)

        c3 = ctk.CTkFrame(main, corner_radius=12, fg_color="#11182d")
        c3.grid(row=0, column=2, sticky="nsew", padx=(6, 0))

        self.tabs = ctk.CTkTabview(c3, fg_color="#11182d", segmented_button_fg_color="#17203d")
        self.tabs.pack(fill="both", expand=True, padx=8, pady=6)
        t_screen = self.tabs.add("Screen (go)")
        t_laptop = self.tabs.add("Laptop Binary")

        self.screen_log = ctk.CTkTextbox(t_screen, font=ctk.CTkFont("Consolas", 12), text_color="#e2e8f0", fg_color="#060912", corner_radius=10)
        self.screen_log.pack(fill="both", expand=True, pady=4)
        self.screen_log.configure(state="disabled")

        led_bar = ctk.CTkFrame(t_laptop, fg_color="#070b15", corner_radius=8)
        led_bar.pack(fill="x", pady=(2, 6))
        self.leds = []
        for _ in range(8):
            lbl = ctk.CTkLabel(led_bar, text="0", width=24, height=28, fg_color="#141d38", text_color="#4f6299", corner_radius=6, font=ctk.CTkFont("Consolas", 13, "bold"))
            lbl.pack(side="left", padx=2, pady=6)
            self.leds.append(lbl)
        ctk.CTkCheckBox(led_bar, text="Pure 0/1", variable=self.pure_binary_var, font=ctk.CTkFont("Segoe UI", 11)).pack(side="right", padx=8)

        self.laptop_log = ctk.CTkTextbox(t_laptop, font=ctk.CTkFont("Consolas", 11), text_color="#34d399", fg_color="#060912", corner_radius=10)
        self.laptop_log.pack(fill="both", expand=True)
        self.laptop_log.configure(state="disabled")

    def insert_snippet(self, text):
        self.code_text.insert("insert", text)
        self.code_text.focus_set()

    def new_rpl_file(self):
        name = simpledialog.askstring("New .rpl File", "Enter file name (example: mygame.rpl):", parent=self.root)
        if not name:
            return
        name = name.strip()
        if not name.endswith(".rpl"):
            name += ".rpl"
        path = os.path.join(APP_DIR, os.path.basename(name))
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write("// " + os.path.basename(path) + "\nadd 3d block dirt.png at 0 0 0\nspawn at 0 3 -4\nstart 3d\n")
        self.load_rpl_path(path)

    def on_file_menu(self, choice):
        if choice == "easy3d.rpl": self.load_rpl_path(EASY3D_PATH)
        elif choice == "hello.rpl": self.load_rpl_path(HELLO_PATH)
        elif choice == "game2d.rpl": self.load_rpl_path(GAME2D_PATH)
        elif choice == "minecraft.rpl": self.load_rpl_path(MINECRAFT_PATH)
        else:
            path = filedialog.askopenfilename(title="Open .rpl File", initialdir=APP_DIR, filetypes=[("RPL Files", "*.rpl"), ("All Files", "*.*")])
            if path: self.load_rpl_path(path)
            else: self.file_switch.set(os.path.basename(self.current_rpl_path))

    def load_rpl_path(self, path):
        self.current_rpl_path = path
        with open(path, "r", encoding="utf-8") as f:
            self.code_text.delete("1.0", "end")
            self.code_text.insert("1.0", f.read())
        self.code_header.configure(text=os.path.basename(path))

    def load_files(self):
        with open(LIB_PATH, "r", encoding="utf-8") as f:
            self.lib_text.delete("1.0", "end")
            self.lib_text.insert("1.0", f.read())
        self.load_rpl_path(self.current_rpl_path)
        self.update_lib_status()

    def update_lib_status(self):
        d, _ = parse_library_content(self.lib_text.get("1.0", "end-1c"))
        self.lib_status.configure(text=f"{len(d)} commands loaded from library.txt")

    def reload_library_from_disk(self):
        if os.path.exists(LIB_PATH):
            with open(LIB_PATH, "r", encoding="utf-8") as f:
                self.lib_text.delete("1.0", "end")
                self.lib_text.insert("1.0", f.read())
            self.update_lib_status()

    def check_downloads_update(self):
        if os.path.exists(DOWNLOADS_LIB_PATH) and os.path.exists(LIB_PATH):
            try:
                if os.path.getmtime(DOWNLOADS_LIB_PATH) > os.path.getmtime(LIB_PATH) + 2:
                    with open(DOWNLOADS_LIB_PATH, "r", encoding="utf-8") as f:
                        content = f.read()
                    ok, count = validate_library_text(content)
                    if ok and messagebox.askyesno("New library.txt Found!", f"A newer library.txt ({count} commands) is in Downloads.\n\nUpdate now?"):
                        safe_write_library(content)
                        self.reload_library_from_disk()
                        self._append_log(self.screen_log, f"[Updater] Updated library.txt ({count} commands).")
            except Exception:
                pass

    def manual_import_downloads(self):
        path = DOWNLOADS_LIB_PATH if os.path.exists(DOWNLOADS_LIB_PATH) else filedialog.askopenfilename(
            title="Select downloaded library.txt",
            initialdir=os.path.join(os.path.expanduser("~"), "Downloads"),
            filetypes=[("Text Files", "*.txt")]
        )
        if not path: return
        try:
            with open(path, "r", encoding="utf-8") as f:
                count = safe_write_library(f.read())
            self.reload_library_from_disk()
            messagebox.showinfo("Updated", f"Updated library.txt ({count} commands)!")
        except Exception as e:
            messagebox.showerror("Update Failed", str(e))

    def save_files(self):
        try:
            self.save_files_silent()
            self.update_lib_status()
            messagebox.showinfo("Saved", f"Saved library.txt and {os.path.basename(self.current_rpl_path)}!")
        except Exception as e:
            messagebox.showerror("Save Error", str(e))

    def save_files_silent(self):
        safe_write_library(self.lib_text.get("1.0", "end-1c"))
        with open(self.current_rpl_path, "w", encoding="utf-8") as f:
            f.write(self.code_text.get("1.0", "end-1c"))

    def open_library_base(self):
        _, meta = parse_library_content(self.lib_text.get("1.0", "end-1c"))
        win = ctk.CTkToplevel(self.root)
        win.title("RPL Library Base - Complete Developer Guide")
        win.geometry("860x680")
        win.attributes("-topmost", True)

        ctk.CTkLabel(win, text="RPL LIBRARY BASE (Complete 3D, 2D, Textures & Python Guide)", font=ctk.CTkFont("Segoe UI", 15, "bold"), text_color="#38bdf8").pack(anchor="w", padx=16, pady=(14, 6))
        box = ctk.CTkTextbox(win, font=ctk.CTkFont("Consolas", 12), fg_color="#080c18")
        box.pack(fill="both", expand=True, padx=14, pady=(0, 14))

        lines = [
            "=== 1. EASY 3D COORDINATE COMMANDS (Works in ANY .rpl file!) ===\n",
            "  add 3d block dirt.png at 0 0 0",
            '  add 3d block "C:/Users/USER/Pictures/wall.png" at 2 1 -3',
            "  fill 3d grass.png from -6 0 -6 to 6 0 6",
            "  remove 3d block at 0 1 0",
            "  spawn at 0 4 -4",
            '  3d title "My 3D Game"',
            '  3d sky "day"          // "day", "night", "sunset", "space" or 3d sky 120 180 255',
            "  3d grid on            // Shows X=Red, Y=Green, Z=Blue lines at (0,0,0)",
            "  3d speed 6            // Player walk speed",
            "  3d jump 9             // Player jump power",
            "  start 3d              // Opens the 3D window!",
            "\n  IN-GAME 3D CONTROLS:",
            "  WASD = Move | Space = Jump | F = Fly Mode | G = Toggle 0,0,0 Grid",
            "  Left Click = Break Block | Right Click = Place Block | 1-9 = Switch Block | ESC = Mouse",
            "\n=== 2. 2D GAME ENGINE WITH .png FILES (use game) ===\n",
            '  game.start(900, 600, "My 2D Game", fps=60)',
            '  game.bg("sky.png")',
            '  game.image("player.png", x, y, 54, 54)',
            '  game.collide(x1, y1, w1, h1, x2, y2, w2, h2)',
            '  game.sound("jump.wav")',
            "  game.rect(x, y, w, h, (r, g, b))",
            "  game.circle(x, y, radius, (r, g, b))",
            '  game.text("Score: 10", 20, 20, 24, (255, 255, 255))',
            '  game.key("w")         // w, a, s, d, space, shift, up, down, left, right',
            "  game.mouse_x(), game.mouse_y(), game.mouse_down(1)",
            "  game.loop(my_update_fn)",
            "\n=== 3. BUILT-IN LIBRARIES (use <name>) ===\n",
            "  use math  -> math.rand(1, 10), math.sin(x), math.cos(x), math.sqrt(x), math.pi",
            "  use text  -> text.upper(s), text.lower(s), text.reverse(s), text.len(s)",
            "  use time  -> time.now(), time.year(), time.wait(ms)",
            '  use file  -> file.save("save.txt", data), file.load("save.txt")',
            '  use ui    -> ui.window("Title", "Msg"), ui.alert("Title", "Msg")',
            "\n=== 4. COMMANDS FROM library.txt ===\n",
        ]
        for cmd, info in meta.items():
            lines.append(f"  {cmd:<14} -> {info['desc'] or 'Binary command'}")
        box.insert("1.0", "\n".join(lines))
        box.configure(state="disabled")

    def _append_log(self, widget, msg):
        widget.configure(state="normal")
        widget.insert("end", msg + "\n")
        widget.see("end")
        widget.configure(state="disabled")

    def _clear_logs(self):
        for w in (self.laptop_log, self.screen_log):
            w.configure(state="normal")
            w.delete("1.0", "end")
            w.configure(state="disabled")

    def _update_leds(self, binary_str):
        chunks = [p for p in binary_str.strip().split() if set(p) <= {"0", "1"}]
        last_byte = chunks[-1] if chunks else "00000000"
        bits = list(last_byte[-8:].rjust(8, "0"))
        for lbl, b in zip(self.leds, bits):
            lbl.configure(text=b, fg_color="#123d31" if b == "1" else "#141d38", text_color="#34d399" if b == "1" else "#4f6299")

    def _open_rpl_window(self, title_text, body_text):
        win = ctk.CTkToplevel(self.root)
        win.title(title_text)
        win.geometry("430x220")
        win.attributes("-topmost", True)
        ctk.CTkLabel(win, text=title_text, font=ctk.CTkFont("Segoe UI", 16, "bold"), text_color="#38bdf8").pack(pady=(26, 8))
        ctk.CTkLabel(win, text=body_text, font=ctk.CTkFont("Consolas", 11), text_color="#34d399", wraplength=380).pack(pady=10, padx=16)

    def _handle_emit(self, kind, payload):
        if kind == "GO":
            self.root.after(0, self._append_log, self.screen_log, f"> {payload}")
        elif kind == "BIN":
            parts = payload.split("|", 2)
            word, binary, extra = parts[0], (parts[1] if len(parts) > 1 else ""), (parts[2] if len(parts) > 2 else "")
            decoded = decode_binary(binary)
            msg = binary if self.pure_binary_var.get() else (f"{word} --> {binary} (decoded: '{decoded}')" if decoded else f"{word} --> {binary}")
            self.root.after(0, self._append_log, self.laptop_log, msg)
            self.root.after(0, self._update_leds, binary)
            action = (decoded or word).lower()
            if action == "open window":
                self.root.after(0, self._open_rpl_window, extra or "RPL Window", "Opened by 8-bit binary:\n" + binary)
            elif action == "beep" and winsound:
                try:
                    winsound.Beep(700, 140)
                except Exception:
                    pass
        elif kind == "UIWIN":
            t, m = payload.split("||", 1)
            self.root.after(0, self._open_rpl_window, t, m)
        elif kind == "ALERT":
            t, m = payload.split("||", 1)
            self.root.after(0, messagebox.showinfo, t, m)
        elif kind == "ERR":
            self.root.after(0, self._append_log, self.screen_log, f"ERROR: {payload}")
        elif kind == "DONE":
            self.root.after(0, self._append_log, self.screen_log, str(payload))

    def stop_rpl(self):
        if self.game_proc and self.game_proc.poll() is None:
            self.game_proc.terminate()
            self._append_log(self.screen_log, "Stopped.")

    def start_rpl(self):
        self.stop_rpl()
        try:
            self.save_files_silent()
        except Exception as e:
            messagebox.showerror("library.txt Error", str(e))
            return

        self._clear_logs()
        code_text = self.code_text.get("1.0", "end-1c")
        lib_text = self.lib_text.get("1.0", "end-1c")

        uses_pygame = bool(re.search(r"(^\s*(use|import)\s+(game|voxel3d)\b|^\s*(start\s+3d|run\s+3d|add\s+3d|fill\s+3d)\b)", code_text, re.M))
        if uses_pygame:
            cmd = [sys.executable, "--run-rpl", self.current_rpl_path] if getattr(sys, "frozen", False) else [sys.executable, os.path.abspath(__file__), "--run-rpl", self.current_rpl_path]
            self.game_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            threading.Thread(target=self._read_proc_output, args=(self.game_proc,), daemon=True).start()
        else:
            threading.Thread(target=self._run_in_thread, args=(code_text, lib_text), daemon=True).start()

    def _read_proc_output(self, proc):
        for raw in proc.stdout:
            line = raw.rstrip("\r\n")
            if line.startswith("__RPL_"):
                tag, _, rest = line[6:].partition("__:")
                self._handle_emit(tag, rest.replace("\\n", "\n"))
            elif line:
                self._handle_emit("GO", line)

    def _run_in_thread(self, code_text, lib_text):
        try:
            run_rpl_code(code_text, lib_text, self._handle_emit)
            self._handle_emit("DONE", "Done.")
        except Exception as e:
            self._handle_emit("ERR", f"{type(e).__name__}: {e}")


if __name__ == "__main__":
    try:
        try:
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Ridwaan.RPLStudio.5")
        except Exception:
            pass

        if "--init-update" in sys.argv:
            ensure_files(overwrite_templates=True)
            sys.exit(0)

        if "--init" in sys.argv:
            ensure_files(overwrite_templates=False)
            sys.exit(0)

        if "--run-rpl" in sys.argv:
            idx = sys.argv.index("--run-rpl")
            if idx + 1 < len(sys.argv):
                run_cli_subprocess(sys.argv[idx + 1])
            sys.exit(0)

        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        root = ctk.CTk()
        RPLStudioApp(root)
        root.mainloop()
    except Exception:
        show_fatal_error(traceback.format_exc())
# ===END_RPL_PY===
