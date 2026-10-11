#!/usr/bin/env python3
"""Convert an image to CP437 ANSI art (.ans) for BBS use.

  uvx --with pillow python make_ansi.py <image> <out.ans> --cols N | --rows N

Default "blocks" style: the image is saturated, snapped to the VGA palette at
full size, then downsampled by majority vote; each text cell shows two square
pixels with half blocks (DF/DC). "shaded" picks the closest of half blocks
and shade blocks (B0/B1/B2) per cell instead (noisier on photos/gradients). Colours are
the 16-colour VGA palette, foreground 0-15 (bold for 8-15), background 0-7
(no iCE colours, so it renders the same in fTelnet, SyncTERM and Synchronet).
Transparent pixels become black. Lines end in CR LF, the colour is reset at
each line end, and a SAUCE record carries the width and height.
"""
import argparse, datetime, struct
from PIL import Image

VGA = [(0,0,0),(170,0,0),(0,170,0),(170,85,0),(0,0,170),(170,0,170),(0,170,170),(170,170,170),
       (85,85,85),(255,85,85),(85,255,85),(255,255,85),(85,85,255),(255,85,255),(85,255,255),(255,255,255)]

def dist(a, b):  # "redmean" perceptual distance, squared
    rm = (a[0] + b[0]) / 2
    dr, dg, db = a[0]-b[0], a[1]-b[1], a[2]-b[2]
    return (2 + rm/256)*dr*dr + 4*dg*dg + (2 + (255-rm)/256)*db*db

def nearest(c, n):
    return min(range(n), key=lambda i: dist(c, VGA[i]))

# Solid-looking cells: (char, fg, bg, apparent colour). Shade blocks mix fg over bg.
SOLIDS = []
for fg in range(16):
    for bg in range(8):
        for ch, r in ((0xB0, .25), (0xB1, .5), (0xB2, .75)):
            if fg == bg: continue
            SOLIDS.append((ch, fg, bg, tuple(VGA[fg][k]*r + VGA[bg][k]*(1-r) for k in range(3))))
    SOLIDS.append((0xDB, fg, 0, VGA[fg]))

def cell(top, bot):
    """Best (char, fg, bg) for a cell whose upper/lower pixels are top/bot."""
    # Half blocks: one half is fg (any of 16), the other bg (0-7).
    best = None
    for ch, fgpx, bgpx in ((0xDF, top, bot), (0xDC, bot, top)):
        fg, bg = nearest(fgpx, 16), nearest(bgpx, 8)
        e = dist(fgpx, VGA[fg]) + dist(bgpx, VGA[bg])
        if best is None or e < best[0]: best = (e, ch, fg, bg)
    for ch, fg, bg, col in SOLIDS:
        e = dist(top, col) + dist(bot, col)
        if e < best[0]: best = (e, ch, fg, bg)
    if best[1] in (0xDF, 0xDC, 0xDB) and best[2] == 0:   # all black: a space
        return (0x20, 7, best[3] if best[1] != 0xDB else 0)
    return best[1:]

def sauce(title, cols, rows, size):
    d = datetime.date.today().strftime('%Y%m%d').encode()
    return (b'\x1aSAUCE00' + title.encode()[:35].ljust(35) + b''.ljust(20) + b''.ljust(20) + d
            + struct.pack('<IBBHHHHBB', size, 1, 1, cols, rows, 0, 0, 0, 0x02)  # 0x02: 8px font, aspect legacy off
            + b'IBM VGA'.ljust(22, b'\0'))

def lab(c):
    """sRGB -> CIELAB (D65), for perceptual nearest-colour matching."""
    def lin(v):
        v /= 255
        return ((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92
    r, g, b = (lin(v) for v in c)
    x = (0.4124*r + 0.3576*g + 0.1805*b) / 0.95047
    y = (0.2126*r + 0.7152*g + 0.0722*b)
    z = (0.0193*r + 0.1192*g + 0.9505*b) / 1.08883
    f = lambda t: t ** (1/3) if t > 0.008856 else 7.787*t + 16/116
    fx, fy, fz = f(x), f(y), f(z)
    return (116*fy - 16, 500*(fx - fy), 200*(fy - fz))

VGA_LAB = [lab(c) for c in VGA]

def nearest_lab(c, cache={}):
    if c not in cache:
        L = lab(c)
        cache[c] = min(range(16), key=lambda i: sum((L[k]-VGA_LAB[i][k])**2 for k in range(3)))
    return cache[c]

def blocks(im, cols, px_h):
    """Snap the full-size image to VGA, then downsample by majority vote so
    flat regions stay flat (no blended edge colours). Returns index grid."""
    w, h = im.size
    src = im.load()
    idx = [[nearest_lab(src[x, y]) for x in range(w)] for y in range(h)]
    grid = []
    for ty in range(px_h):
        y0, y1 = ty * h // px_h, max(ty * h // px_h + 1, (ty + 1) * h // px_h)
        row = []
        for tx in range(cols):
            x0, x1 = tx * w // cols, max(tx * w // cols + 1, (tx + 1) * w // cols)
            votes = {}
            for y in range(y0, y1):
                for x in range(x0, x1):
                    votes[idx[y][x]] = votes.get(idx[y][x], 0) + 1
            row.append(max(votes, key=votes.get))
        grid.append(row)
    return grid

def block_cell(t, b):
    """(char, fg, bg) for upper/lower VGA indices; bg must be 0-7."""
    if t == b:
        return (0x20, 7, t) if t < 8 else (0xDB, t, 0)
    if b < 8:
        return (0xDF, t, b)
    if t < 8:
        return (0xDC, b, t)
    return (0xDF, t, b - 8)            # both bright: dim the lower half

def strip_outline(im, lum=200, chroma=40):
    """Make the white sticker outline transparent: flood-fill from the
    transparent background through near-white, low-colour pixels. Enclosed
    white (the BOARD lettering) isn't reachable, so it stays."""
    w, h = im.size
    px = im.load()
    def whiteish(c):
        r, g, b, a = c
        return a < 128 or (min(r, g, b) >= lum and max(r, g, b) - min(r, g, b) <= chroma)
    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or seen[y*w + x]: continue
        seen[y*w + x] = 1
        if not whiteish(px[x, y]): continue
        px[x, y] = (0, 0, 0, 0)
        stack += ((x+1, y), (x-1, y), (x, y+1), (x, y-1))
    return im

# Bold pixel fonts for re-lettering the sign ("#" = lit).
FONT_LARGE = {  # 5 x 7
    'B': ["####.", "##.##", "##.##", "####.", "##.##", "##.##", "####."],
    'E': ["#####", "##...", "##...", "####.", "##...", "##...", "#####"],
    'A': [".###.", "##.##", "##.##", "#####", "##.##", "##.##", "##.##"],
    'N': ["##.##", "###.#", "#####", "#####", "##.##", "##.##", "##.##"],
    'O': [".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###."],
    'R': ["####.", "##.##", "##.##", "####.", "####.", "##.##", "##.##"],
    'D': ["####.", "##.##", "##.##", "##.##", "##.##", "##.##", "####."],
}
FONT_SMALL = {  # 4 x 5
    'B': ["###.", "##.#", "###.", "##.#", "###."],
    'E': ["####", "##..", "###.", "##..", "####"],
    'A': [".##.", "##.#", "####", "##.#", "##.#"],
    'N': ["##.#", "####", "####", "##.#", "##.#"],
    'O': [".##.", "##.#", "##.#", "##.#", ".##."],
    'R': ["###.", "##.#", "###.", "##.#", "##.#"],
    'D': ["###.", "##.#", "##.#", "##.#", "###."],
}
FONT_TINY = {  # 3 x 5
    'B': ["##.", "#.#", "##.", "#.#", "##."],
    'E': ["###", "#..", "##.", "#..", "###"],
    'A': [".#.", "#.#", "###", "#.#", "#.#"],
    'N': ["#.#", "###", "###", "#.#", "#.#"],
    'O': ["###", "#.#", "#.#", "#.#", "###"],
    'R': ["##.", "#.#", "##.", "#.#", "#.#"],
    'D': ["##.", "#.#", "#.#", "#.#", "##."],
}
WOOD, PLATE, INK, SHADOW = 3, 1, 15, 0
GREYS, REDS = {7, 8, 15}, {1, 9}

def outside_mask(grid):
    """Black pixels connected to the image border (the background)."""
    H, W = len(grid), len(grid[0])
    out = [[False] * W for _ in range(H)]
    stack = [(x, y) for x in range(W) for y in (0, H-1)] + [(x, y) for y in range(H) for x in (0, W-1)]
    while stack:
        x, y = stack.pop()
        if 0 <= x < W and 0 <= y < H and not out[y][x] and grid[y][x] == 0:
            out[y][x] = True
            stack += ((x+1, y), (x-1, y), (x, y+1), (x, y-1))
    return out

def clean_edges(grid, iters=2):
    """Remove what's left of the white sticker outline (grey/white pixels
    touching the background), and lone grey specks. Pupils and eye glints
    aren't connected to the background, so they stay."""
    H, W = len(grid), len(grid[0])
    for _ in range(iters):
        out = outside_mask(grid)
        hit = [(x, y) for y in range(H) for x in range(W) if grid[y][x] in GREYS and any(
            0 <= x+dx < W and 0 <= y+dy < H and out[y+dy][x+dx] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))]
        for x, y in hit: grid[y][x] = 0
    # Distance (in pixels) from the background, to tell rim from interior.
    out = outside_mask(grid)
    dist = [[0 if out[y][x] else 99 for x in range(W)] for y in range(H)]
    frontier = [(x, y) for y in range(H) for x in range(W) if out[y][x]]
    d = 0
    while frontier:
        d += 1
        nxt = []
        for x, y in frontier:
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                xx, yy = x+dx, y+dy
                if 0 <= xx < W and 0 <= yy < H and dist[yy][xx] > d:
                    dist[yy][xx] = d; nxt.append((xx, yy))
        frontier = nxt
    # Outline caught inside the bean's own dark rim: white/grey within 3px of
    # the background and touching green becomes green (eyes are deeper in).
    for y in range(H):
        for x in range(W):
            if grid[y][x] in GREYS and dist[y][x] <= 3 and any(
                    0 <= x+dx < W and 0 <= y+dy < H and grid[y+dy][x+dx] in GREENS
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                grid[y][x] = 10
    # Tiny fragments (< 5 px) touching the background are conversion noise.
    seen = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if seen[y][x] or grid[y][x] == 0: continue
            comp, stack, touches = [], [(x, y)], False
            seen[y][x] = True
            while stack:
                cx, cy = stack.pop(); comp.append((cx, cy))
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    xx, yy = cx+dx, cy+dy
                    if 0 <= xx < W and 0 <= yy < H:
                        if out[yy][xx]: touches = True
                        elif not seen[yy][xx] and grid[yy][xx] == grid[cy][cx]:
                            seen[yy][xx] = True; stack.append((xx, yy))
            if touches and len(comp) < 5 and grid[y][x] not in GREENS:
                for cx, cy in comp: grid[cy][cx] = 0
    for y in range(1, H-1):
        for x in range(1, W-1):
            n = {grid[y-1][x], grid[y+1][x], grid[y][x-1], grid[y][x+1]}
            if grid[y][x] in {7, 8} and len(n) == 1:
                grid[y][x] = n.pop()
    return grid
GREENS = {2, 10}

def reletter(grid, words=("BEAN", "BOARD")):
    """Repaint the wooden board's text: clear its middle to wood and draw the
    words in a bold pixel font -- the first on a red plate (as on the logo),
    the second in white with a dark drop shadow."""
    H, W = len(grid), len(grid[0])
    wood = [(x, y) for y in range(H // 3, H) for x in range(W) if grid[y][x] == WOOD]
    if not wood:
        return grid
    ys = sorted(y for _, y in wood)
    top, bot = ys[len(ys) // 20], ys[-len(ys) // 20 - 1]     # ignore stray wood pixels
    spans = {}
    for x, y in wood:
        lo, hi = spans.get(y, (x, x))
        spans[y] = (min(lo, x), max(hi, x))
    # Text band: the board's middle, left/right bounded by the wood on each row.
    band_top, band_bot = top + 1, bot - 1
    rows = [y for y in range(band_top, band_bot + 1) if y in spans]
    if not rows:
        return grid
    left = max(spans[y][0] for y in rows)
    right = min(spans[y][1] for y in rows)
    avail = right - left + 1 - 4                              # breathing room
    for font in (FONT_LARGE, FONT_SMALL, FONT_TINY):
        gw, gh = len(font['B'][0]), len(font['B'])
        widths = [len(wd) * gw + (len(wd) - 1) for wd in words]
        gap = gw - 1
        total = sum(widths) + gap + 4                          # +plate padding
        if total <= avail and gh + 2 <= band_bot - band_top + 1:
            break
    else:
        return grid                                            # no room: leave the logo's lettering
    for y in rows:                                             # clear the band to wood
        lo, hi = spans[y]
        for x in range(lo, hi + 1):
            if grid[y][x] not in GREENS:
                grid[y][x] = WOOD
    for y in range(max(0, top - 3), band_top):                 # board's top edge: no outline remnants
        lo, hi = spans.get(y, spans.get(top))
        for x in range(W):
            if grid[y][x] in GREYS | REDS | {11}:
                grid[y][x] = WOOD if (y >= top and lo <= x <= hi) else 0
    for y in range(band_bot + 1, H):                           # underside: dark-red streaks
        lo, hi = spans.get(y, (W, -1))
        for x in range(W):
            if grid[y][x] in REDS | GREYS | {11}:
                grid[y][x] = WOOD if (y <= bot and lo - 1 <= x <= hi + 1) else 0
    x = left + 2 + (avail - total) // 2 + 2
    y0 = band_top + ((band_bot - band_top + 1) - gh) // 2
    def glyph(ch, gx, color, shadow):
        for r, line in enumerate(font[ch]):
            for c, bit in enumerate(line):
                if bit == '#':
                    if shadow is not None:
                        for dx, dy in ((1, 1), (0, 1), (1, 0)):
                            yy, xx = y0 + r + dy, gx + c + dx
                            if grid[yy][xx] == WOOD: grid[yy][xx] = shadow
                    grid[y0 + r][gx + c] = color
    for i, wd in enumerate(words):
        if i == 0:   # red plate behind the first word
            for yy in range(y0 - 1, y0 + gh + 1):
                for xx in range(x - 2, x + widths[0] + 2):
                    grid[yy][xx] = PLATE
            gx = x
            for ch in wd:
                glyph(ch, gx, INK, None); gx += gw + 1
            x += widths[0] + 2 + gap
        else:
            gx = x
            for ch in wd:
                glyph(ch, gx, INK, SHADOW); gx += gw + 1
            x += widths[i] + gap
    return grid

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('image'); ap.add_argument('out')
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--cols', type=int); g.add_argument('--rows', type=int)
    ap.add_argument('--width', type=int, default=80, help='screen width to centre in')
    ap.add_argument('--title', default='The Bean Board')
    ap.add_argument('--saturation', type=float, default=2.2,
                    help='boost colour first, so muted tones (the tan sign) map to VGA hues, not grey')
    ap.add_argument('--keep-outline', action='store_true', help="keep the logo's white sticker outline")
    ap.add_argument('--no-reletter', action='store_true', help="keep the logo's own (shrunken) lettering")
    ap.add_argument('--style', choices=['blocks', 'shaded'], default='blocks',
                    help='blocks: flat half-block pixel art (default); shaded: per-cell best fit with shade characters')
    a = ap.parse_args()

    from PIL import ImageEnhance
    im = Image.open(a.image).convert('RGBA')
    if not a.keep_outline:
        im = strip_outline(im)
    im = im.crop(im.getbbox())                       # trim transparent margins
    bg = Image.new('RGBA', im.size, (0, 0, 0, 255))
    im = Image.alpha_composite(bg, im).convert('RGB')
    im = ImageEnhance.Color(im).enhance(a.saturation)
    w, h = im.size
    cols = a.cols or round(a.rows * 2 * w / h)
    px_h = round(h * cols / w)
    px_h += px_h % 2

    if a.style == 'blocks':
        grid = blocks(im, cols, px_h)
        if not a.keep_outline:
            grid = clean_edges(grid)
        if not a.no_reletter:
            grid = reletter(grid)
        rows_cells = [[block_cell(grid[y][x], grid[y+1][x]) for x in range(cols)] for y in range(0, px_h, 2)]
    else:
        px = im.resize((cols, px_h), Image.LANCZOS).load()
        rows_cells = [[cell(px[x, y], px[x, y+1]) for x in range(cols)] for y in range(0, px_h, 2)]

    pad = max(0, (a.width - 1 - cols) // 2)          # stay off column 80 (autowrap)
    out = bytearray()
    for cells in rows_cells:
        while cells and cells[-1][0] == 0x20 and cells[-1][2] == 0: cells.pop()
        line, state = bytearray(b' ' * pad), None
        for ch, fg, bg_ in cells:
            want = (fg, bg_) if ch != 0x20 else (None, bg_)
            if ch == 0x20 and state and state[1] == bg_: want = state
            if want != state:
                f = want[0] if want[0] is not None else 7
                line += b'\x1b[0;' + (b'1;' if f > 7 else b'') + b'%d;%dm' % (30 + f % 8, 40 + bg_)
                state = want
            line.append(ch)
        out += line + b'\x1b[0m\r\n'
    rows = px_h // 2
    open(a.out, 'wb').write(bytes(out) + sauce(a.title, a.width, rows, len(out)))
    print(f'{a.out}: {cols}x{rows} art, centred in {a.width} columns, {len(out)} bytes')

if __name__ == '__main__':
    main()
