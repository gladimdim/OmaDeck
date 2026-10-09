"""Generate the OmaDeck banner: a pixel-art Steam Deck showing the Omarchy icon.

    python3 assets/generate-banner.py assets/omadeck.svg
    rsvg-convert assets/omadeck.svg -o assets/omadeck.png
"""
import math
import sys

OUT = sys.argv[1]
W, H = 1280, 640
U = 10  # deck pixel size

BG, BG2 = "#1a1b26", "#13141c"
BODY, EDGE, SHADE, DARK = "#2a2e42", "#414868", "#232637", "#15161e"
GREEN, FG, MUTED, BLUE = "#9ece6a", "#c0caf5", "#565f89", "#7aa2f7"

parts = []


def runs_to_rects(cells, unit, ox, oy, fill, extra=""):
    """Merge a set of (x, y) cells into row runs, then stack equal runs vertically."""
    rows = {}
    for x, y in cells:
        rows.setdefault(y, []).append(x)
    runs = {}
    for y, xs in rows.items():
        xs.sort()
        start = prev = xs[0]
        for x in xs[1:] + [None]:
            if x is not None and x == prev + 1:
                prev = x
                continue
            runs.setdefault((start, prev), []).append(y)
            if x is not None:
                start = prev = x
    out = []
    for (x0, x1), ys in runs.items():
        ys.sort()
        y0 = prev = ys[0]
        for y in ys[1:] + [None]:
            if y is not None and y == prev + 1:
                prev = y
                continue
            out.append(
                f'<rect x="{ox + x0 * unit:g}" y="{oy + y0 * unit:g}" '
                f'width="{(x1 - x0 + 1) * unit:g}" height="{(prev - y0 + 1) * unit:g}"/>'
            )
            if y is not None:
                y0 = prev = y
    return f'<g fill="{fill}"{extra}>' + "".join(out) + "</g>"


def rrect(x0, y0, x1, y1, r):
    """Cells of a rounded rectangle [x0, x1) x [y0, y1) with stair-stepped corners."""
    cells = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            cx = min(max(x + 0.5, x0 + r), x1 - r)
            cy = min(max(y + 0.5, y0 + r), y1 - r)
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                cells.add((x, y))
    return cells


def disc(cx, cy, r):
    return {
        (x, y)
        for y in range(math.floor(cy - r) - 1, math.ceil(cy + r) + 1)
        for x in range(math.floor(cx - r) - 1, math.ceil(cx + r) + 1)
        if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r
    }


def edge(cells):
    return {
        (x, y)
        for x, y in cells
        if any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    }


def deck(cells, fill, extra=""):
    parts.append(runs_to_rects(cells, U, 0, 0, fill, extra))


# --- Background -------------------------------------------------------------
parts.append(
    f"""<defs>
  <radialGradient id="bg" cx="50%" cy="38%" r="75%">
    <stop offset="0" stop-color="{BG}"/><stop offset="1" stop-color="{BG2}"/>
  </radialGradient>
  <radialGradient id="glow" cx="50%" cy="50%" r="50%">
    <stop offset="0" stop-color="{GREEN}" stop-opacity=".35"/>
    <stop offset="1" stop-color="{GREEN}" stop-opacity="0"/>
  </radialGradient>
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  <pattern id="dots" width="20" height="20" patternUnits="userSpaceOnUse">
    <rect x="9" y="9" width="2" height="2" fill="{FG}" opacity=".05"/>
  </pattern>
</defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<rect width="{W}" height="{H}" fill="url(#dots)"/>
<ellipse cx="640" cy="230" rx="430" ry="230" fill="url(#glow)"/>"""
)

# A few floating pixels, like the icon's blocks drifting off the screen.
for x, y, s, o in [(120, 70, 10, 0.5), (150, 110, 6, 0.3), (1150, 90, 10, 0.45), (1180, 140, 6, 0.3),
                   (90, 330, 8, 0.25), (1200, 360, 8, 0.25), (210, 40, 6, 0.2), (1070, 40, 6, 0.2)]:
    parts.append(f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="{GREEN}" opacity="{o}"/>')

# --- Deck body (grid of 10px cells; 128 x 64) -------------------------------
X0, X1, Y0, Y1 = 14, 114, 3, 41
body = rrect(X0, Y0, X1, Y1, 9)
# The grips bulge out below the ends.
body |= rrect(X0, Y0 + 14, X0 + 22, Y1 + 4, 9) | rrect(X1 - 22, Y0 + 14, X1, Y1 + 4, 9)

shadow = {(x + 1, y + 2) for x, y in body}
deck(shadow, "#000", ' opacity=".35"')
deck(body, BODY)
deck({(x, y) for x, y in body if y >= Y1 - 1}, SHADE)
deck(edge(body), EDGE)
# Top highlight.
deck({(x, Y0) for x in range(X0 + 10, X1 - 10)}, "#565f89")

# --- Screen -----------------------------------------------------------------
SX0, SX1, SY0, SY1 = 38, 90, 6, 38
deck(rrect(SX0, SY0, SX1, SY1, 2), DARK)
DX0, DX1, DY0, DY1 = SX0 + 2, SX1 - 2, SY0 + 2, SY1 - 2  # 48 x 28 display
parts.append(f'<rect x="{DX0 * U}" y="{DY0 * U}" width="{(DX1 - DX0) * U}" height="{(DY1 - DY0) * U}" fill="{BG}"/>')
# Omarchy top bar: workspaces on the left, clock on the right.
parts.append(f'<rect x="{DX0 * U}" y="{DY0 * U}" width="{(DX1 - DX0) * U}" height="14" fill="{BG2}"/>')
for i, c in enumerate([GREEN, MUTED, MUTED, MUTED]):
    parts.append(f'<rect x="{DX0 * U + 8 + i * 12}" y="{DY0 * U + 4}" width="6" height="6" fill="{c}"/>')
parts.append(f'<rect x="{(DX0 + DX1) * U // 2 - 18}" y="{DY0 * U + 5}" width="36" height="4" fill="{MUTED}"/>')
for i in range(3):
    parts.append(f'<rect x="{DX1 * U - 14 - i * 10}" y="{DY0 * U + 4}" width="6" height="6" fill="{MUTED}"/>')

# The Omarchy icon (traced from /usr/share/omarchy/icon.png: 15 x 15 blocks).
ICON = [
    "###############",
    "#......#......#",
    "#.######...##.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "###.........#.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "#.#.........#.#",
    "#.###########.#",
    "#......#......#",
    "########.######",
]
B = 13
icon = {(x, y) for y, row in enumerate(ICON) for x, ch in enumerate(row) if ch == "#"}
ix = (DX0 + DX1) * U / 2 - 15 * B / 2
iy = (DY0 * U + 14 + DY1 * U) / 2 - 15 * B / 2
parts.append(runs_to_rects(icon, B, ix, iy, GREEN, ' filter="url(#soft)" opacity=".8"'))
parts.append(runs_to_rects(icon, B, ix, iy, GREEN))

# Glass sheen.
parts.append(
    f'<polygon points="{DX0 * U},{DY0 * U + 14} {DX0 * U + 120},{DY0 * U + 14} {DX0 * U + 40},{DY1 * U} {DX0 * U},{DY1 * U}" '
    f'fill="{FG}" opacity=".035"/>'
)

# --- Controls ---------------------------------------------------------------
def stick(cx, cy):
    deck(disc(cx, cy, 4.6), DARK)
    deck(disc(cx, cy, 3.2), "#2f334d")
    deck(edge(disc(cx, cy, 3.2)), EDGE)
    deck({(math.floor(cx) - 1, math.floor(cy) - 2), (math.floor(cx), math.floor(cy) - 2)}, "#6b7394")


def trackpad(x0, y0, size):
    deck(rrect(x0, y0, x0 + size, y0 + size, 1.5), "#202333")
    # Green corner brackets echo the Omarchy icon.
    for (bx, by, dx, dy) in [(x0, y0, 1, 1), (x0 + size - 1, y0, -1, 1), (x0, y0 + size - 1, 1, -1),
                             (x0 + size - 1, y0 + size - 1, -1, -1)]:
        deck({(bx, by), (bx + dx, by), (bx + 2 * dx, by), (bx, by + dy), (bx, by + 2 * dy)}, GREEN, ' opacity=".75"')


# Left: D-pad, stick, trackpad.
dpad = {(x, y) for x in range(19, 28) for y in range(13, 16)} | {(x, y) for x in range(22, 25) for y in range(10, 19)}
deck(dpad, DARK)
deck({(23, 11), (23, 17), (20, 14), (26, 14)}, "#3b3f57")
stick(31.5, 10.5)
trackpad(19, 24, 13)

# Right: ABXY, stick, trackpad (mirrored).
for (bx, by), col in [((104, 10), FG), ((101, 13), FG), ((107, 13), FG), ((104, 16), GREEN)]:
    deck(rrect(bx, by, bx + 3, by + 3, 1.2), DARK)
    deck({(bx + 1, by + 1)}, col)
stick(96.5, 10.5)
trackpad(96, 24, 13)

# Small buttons beside the screen.
for x in (34, 92):
    deck({(x, 6), (x + 1, 6)}, DARK)
    deck({(x, 37), (x + 1, 37)}, DARK)

# --- Wordmark: "omadeck" in Omarchy's own pixel lettering --------------------
GLYPHS = {
    # o, m, a, c traced from /usr/share/omarchy/logo.svg (15px grid).
    "o": ["..#####..", ".#######.", "###...###", "###...###", "###...###", "###...###", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", "###...###", "###...###",
          ".#######.", "..#####.."],
    "m": ["..###########..", ".#############.", "###...###...###", "###...###...###", "###...###...###",
          "###...###...###", "###...###...###", "###...###...###", "###...###...###", "###...###...###",
          "###...###...###", "###...###...###", "###...###...###", "###...###...###", ".##...###...##.",
          "..#...###...#.."],
    "a": ["...#######", "..########", ".###...###", ".###...###", ".###...###", ".###...###", ".###...###",
          "##########", "##########", ".###...###", ".###...###", ".###...###", ".###...###", ".###...###",
          ".###...##.", ".###...#.."],
    "c": ["..#######", ".########", "###...###", "###...###", "###...##.", "###...#..", "###......",
          "###......", "###......", "###...#..", "###...##.", "###...###", "###...###", "###...###",
          "########.", "#######.."],
    # d, e, k drawn to match.
    "d": ["#######..", "########.", "###...###", "###...###", "###...###", "###...###", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", "###...###", "###...###",
          "########.", "#######.."],
    "e": ["..#######", ".########", "###...###", "###...###", "###...###", "###...###", "###...###",
          "#########", "#########", "###......", "###......", "###...#..", "###...##.", "###...###",
          "########.", "#######.."],
    "k": ["###....##", "###...###", "###...###", "###...###", "###...###", "###..###.", "###.###..",
          "#######..", "#######..", "###.###..", "###..###.", "###...###", "###...###", "###...###",
          "###...###", "###...###"],
}
P = 6
word = "omadeck"
gap = 2
width = sum(len(GLYPHS[ch][0]) for ch in word) + gap * (len(word) - 1)
x = (W - width * P) / 2
y = 470
for i, ch in enumerate(word):
    cells = {(cx, cy) for cy, row in enumerate(GLYPHS[ch]) for cx, v in enumerate(row) if v == "#"}
    parts.append(runs_to_rects(cells, P, x, y, FG if i < 3 else GREEN))
    x += (len(GLYPHS[ch][0]) + gap) * P

parts.append(
    f'<text x="{W / 2}" y="{y + 16 * P + 42}" text-anchor="middle" fill="{MUTED}" '
    f'font-family="JetBrains Mono, Menlo, Consolas, ui-monospace, monospace" font-size="22" letter-spacing="1">'
    f'fixes that make <tspan fill="{FG}">omarchy</tspan> great on the <tspan fill="{FG}">steam deck</tspan></text>'
)

svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
    f'shape-rendering="crispEdges">\n<title>OmaDeck</title>\n' + "\n".join(parts) + "\n</svg>\n"
)
open(OUT, "w").write(svg)
print(f"wrote {OUT} ({len(svg)} bytes)")
