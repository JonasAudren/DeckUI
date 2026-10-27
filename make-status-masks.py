"""make-status-masks.py - the masks for the buff bar (DeckUI_Orbs/buffs.lua) and the
action bars' rounded slot (DeckUI_Cross/bars.lua).

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


# The action bars' slot (DeckUI_Cross/bars.lua): FFXIV's square with rounded
# corners, radius 10 of 64.
CROSS_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "DeckUI_Cross", "textures")
RADIUS = 10


def rounded(x, y):
    hits = 0
    for sx in range(4):
        for sy in range(4):
            px = x + (sx + 0.5) / 4
            py = y + (sy + 0.5) / 4
            # distance into the nearest corner's circle, if inside a corner box
            cx = min(max(px, RADIUS), N - RADIUS)
            cy = min(max(py, RADIUS), N - RADIUS)
            hits += (px - cx) ** 2 + (py - cy) ** 2 <= RADIUS ** 2
    return hits / 16


pixels = bytearray()
for y in range(N):
    for x in range(N):
        a = int(round(rounded(x, y) * 255))
        v = 255 if a > 0 else 0
        pixels += bytes((v, v, v, a))
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28)
with open(os.path.join(CROSS_OUT, "slot_rounded.tga"), "wb") as f:
    f.write(header + pixels)
print("written to " + CROSS_OUT)


# The "Final Fantasy XIV" style's bars (DeckUI_Orbs/ffstyle.lua): capsules of any
# length, so the round ends are two masks of their own - a half disc on one side,
# white on the other - anchored square at each end of a bar and loaded with
# CLAMPTOWHITE, which leaves everything outside them untouched.
def cap(x, y, left):
    hits = 0
    for sx in range(4):
        for sy in range(4):
            px = x + (sx + 0.5) / 4
            py = y + (sy + 0.5) / 4
            straight = px >= N / 2 if left else px <= N / 2
            hits += straight or (px - N / 2) ** 2 + (py - N / 2) ** 2 <= (N / 2) ** 2
    return hits / 16


for name, left in (("bar_cap_left.tga", True), ("bar_cap_right.tga", False)):
    pixels = bytearray()
    for y in range(N):
        for x in range(N):
            a = int(round(cap(x, y, left) * 255))
            v = 255 if a > 0 else 0
            pixels += bytes((v, v, v, a))
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + pixels)
print("bar caps written to " + OUT)


# The target arrow over the target's nameplate (DeckUI/targetarrow.lua): FFXIV's
# arrowhead pointing down, with a notch in its top edge. White on transparent; the
# addon colours it and lays a larger black copy behind it as the outline.
HUB_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "DeckUI", "textures")
ARROW = [(6, 6), (32, 22), (58, 6), (32, 60)]   # clockwise, y grows down


def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


pixels = bytearray()
for y in range(N):
    for x in range(N):
        hits = sum(inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4, ARROW) for sx in range(4) for sy in range(4))
        a = int(round(hits / 16 * 255))
        v = 255 if a > 0 else 0
        pixels += bytes((v, v, v, a))
os.makedirs(HUB_OUT, exist_ok=True)
with open(os.path.join(HUB_OUT, "target_arrow.tga"), "wb") as f:
    f.write(header + pixels)
print("target arrow written to " + HUB_OUT)


# The rank mark on enemies (DeckUI/rankmark.lua): FFXIV-like emblems before a name -
# a diamond badge, and a star (rare) or a crown (boss) laid on it. White on
# transparent; the addon tints them and lays a larger black diamond behind as the edge.
import math

DIAMOND = [(32, 2), (62, 32), (32, 62), (2, 32)]
STAR = []
for k in range(10):
    r = 22 if k % 2 == 0 else 9
    a = -math.pi / 2 + k * math.pi / 5
    STAR.append((32 + r * math.cos(a), 34 + r * math.sin(a)))
CROWN = [(12, 46), (12, 20), (22, 32), (32, 14), (42, 32), (52, 20), (52, 46)]


def shape(name, poly):
    out = bytearray()
    for y in range(N):
        for x in range(N):
            hits = sum(inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4, poly) for sx in range(4) for sy in range(4))
            a = int(round(hits / 16 * 255))
            v = 255 if a > 0 else 0
            out += bytes((v, v, v, a))
    with open(os.path.join(HUB_OUT, name), "wb") as f:
        f.write(header + out)


for name, poly in (("rank_diamond.tga", DIAMOND), ("rank_star.tga", STAR), ("rank_crown.tga", CROWN)):
    shape(name, poly)
print("rank marks written to " + HUB_OUT)
