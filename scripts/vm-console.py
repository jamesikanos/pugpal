#!/usr/bin/env python3
"""Drive the test VM's screen through the QEMU monitor (vm/monitor.sock).

  scripts/vm-console.py shot out.png     screenshot of the VM display
  scripts/vm-console.py type 'text'      type text (\\n = Enter)
  scripts/vm-console.py key ret          press one key (QEMU key name, e.g. ctrl-alt-f2)

For testing what happens on the console before anyone can log in, e.g. the
first-boot setup on tty1. Start the VM with `just vm` first.
"""
import os
import socket
import struct
import sys
import tempfile
import time
import zlib

SOCK = os.path.join(os.path.dirname(__file__), "..", "vm", "monitor.sock")

SHIFTED = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8',
           '(': '9', ')': '0', '_': 'minus', '+': 'equal', '{': 'bracket_left',
           '}': 'bracket_right', ':': 'semicolon', '"': 'apostrophe', '<': 'comma',
           '>': 'dot', '?': 'slash', '|': 'backslash', '~': 'grave_accent'}
PLAIN = {' ': 'spc', '\n': 'ret', '-': 'minus', '=': 'equal', '[': 'bracket_left',
         ']': 'bracket_right', ';': 'semicolon', "'": 'apostrophe', ',': 'comma',
         '.': 'dot', '/': 'slash', '\\': 'backslash', '`': 'grave_accent', '\t': 'tab'}


def monitor(*commands):
    s = socket.socket(socket.AF_UNIX)
    s.connect(SOCK)
    s.settimeout(2)
    time.sleep(0.1)
    try:
        s.recv(65536)  # banner
    except socket.timeout:
        pass
    for c in commands:
        s.sendall(c.encode() + b"\n")
        time.sleep(0.05)
    time.sleep(0.2)
    s.close()


def keyname(ch):
    if ch.isalpha():
        return f"shift-{ch.lower()}" if ch.isupper() else ch
    if ch.isdigit():
        return ch
    if ch in SHIFTED:
        return f"shift-{SHIFTED[ch]}"
    return PLAIN[ch]


def ppm_to_png(ppm, png):
    data = open(ppm, "rb").read()
    parts = data.split(maxsplit=4)  # P6 w h maxval pixels
    w, h = int(parts[1]), int(parts[2])
    pixels = parts[4]
    raw = b"".join(b"\x00" + pixels[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    with open(png, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, arg = sys.argv[1], sys.argv[2]
    if cmd == "shot":
        ppm = os.path.join(tempfile.mkdtemp(), "screen.ppm")
        monitor(f"screendump {ppm}")
        for _ in range(20):
            if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
                break
            time.sleep(0.2)
        time.sleep(0.3)
        ppm_to_png(ppm, arg)
    elif cmd == "type":
        monitor(*(f"sendkey {keyname(c)}" for c in arg.encode().decode("unicode_escape")))
    elif cmd == "key":
        monitor(f"sendkey {arg}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
