"""make-status-masks.py - the masks for the buff bar (DeckUI_Orbs/buffs.lua).

FFXIV's status icons are shaped:
  status_up.tga    a rectangle whose top edge rises to a point in the middle (a roof) - buffs
  status_down.tga  a rectangle whose bottom edge falls to a point in the middle - debuffs
64x64, 32-bit uncompressed TGA with a top-left origin, white inside with full alpha, black and
transparent outside, with a soft edge (4x4 supersampling) so the slant does not look jagged.

Run it from anywhere; it writes into DeckUI_Orbs/textures next to this script.
The game reads textures only at startup: a new or changed file needs a full client restart.
"""
import os
import struct

N = 64
PEAK = 12   # how far the point stands out, in pixels of 64
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "DeckUI_Orbs", "textures")


def coverage(x, y, up):
    hits = 0
    for sx in range(4):
        for sy in range(4):
            px = x + (sx + 0.5) / 4
            py = y + (sy + 0.5) / 4
            d = abs(px - N / 2) / (N / 2)   # 0 in the middle, 1 at the sides
            edge = PEAK * d                 # the slanted edge's offset from the point
            inside = py >= edge if up else py <= N - edge
            hits += inside
    return hits / 16


def write(name, up):
    pixels = bytearray()
    for y in range(N):
        for x in range(N):
            a = int(round(coverage(x, y, up) * 255))
            v = 255 if a > 0 else 0
            pixels += bytes((v, v, v, a))   # B, G, R, A
    # id length, colour map type, image type 2 (true colour), colour map spec,
    # origin, size, 32 bits per pixel, descriptor: 8 alpha bits + top-left origin
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + pixels)


write("status_up.tga", True)
write("status_down.tga", False)
print("written to " + OUT)
