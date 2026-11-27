"""UI panel art for the field guide and the tackle box (leg 3, N2).

Draws every UI image by script (Pillow + numpy + scipy, no Blender needed) so the whole set can
be rebuilt and tweaked:

    python art/scripts/ui_art.py            # all images, README table, sheet and phone mockups
    python art/scripts/ui_art.py --no-sheet # images and README only

Outputs go to art/ui/ (PNG with alpha, colour bled into the transparent pixels so Roblox does
not show dark fringes), the preview sheet to art/ui/sheet.png and the 667 x 375 phone mockups to
art/ui/preview/.

How it draws: everything is painted at 4x and averaged down. Shapes are signed distance fields
with a little noise on the edge (the handmade wobble); surfaces are low-contrast noise so text
on top keeps its contrast, and anything inside a nine-slice stretch zone is either flat or a
continuous line, never a repeating mark (repeats smear when Roblox stretches the centre).
The SPEC list at the bottom of this file is the one source for sizes, slice centres and uses;
README.md is written from it.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

S = 4  # supersample factor
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "ui"))
PREVIEW = os.path.join(OUT, "preview")
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))

# Plan colours (docs/superpowers/plans/2026-11-27-leg-3.md, "UI and signs").
PAPER = (236, 226, 200)
INK = (38, 34, 30)
BRASS = (176, 136, 72)
# Chosen here (the plan names the materials, not the numbers).
CANVAS = (188, 170, 126)
LEATHER = (120, 78, 48)
THREAD = (230, 214, 172)
WOOD = (122, 92, 62)
WATER = (44, 104, 140)
MANILA = (228, 212, 172)
INKBROWN = (50, 38, 28)

RARITY = [  # src/ReplicatedStorage/Shared/Rarity.luau, unchanged
    ("Common", (175, 180, 185)),
    ("Uncommon", (95, 200, 110)),
    ("Rare", (80, 150, 240)),
    ("Epic", (170, 95, 235)),
    ("Legendary", (250, 175, 40)),
    ("Mythic", (240, 75, 125)),
]


def c(rgb):
    return np.array(rgb, np.float32) / 255.0


# ----------------------------------------------------------------------------- basics

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def cov(d):
    """Coverage from a signed distance in final pixels (negative inside)."""
    return np.clip(0.5 - d * S, 0.0, 1.0)


def blur(a, px):
    return ndi.gaussian_filter(a, px * S, mode="nearest")


def vnoise(w, h, cx, cy, seed):
    r = np.random.default_rng(seed)
    gw = max(2, int(round(w / cx)) + 1)
    gh = max(2, int(round(h / cy)) + 1)
    a = r.random((gh, gw)).astype(np.float32)
    return np.asarray(Image.fromarray(a).resize((w * S, h * S), Image.BICUBIC)) * 2 - 1


def fbm(w, h, cell, seed, octaves=3, aspect=1.0):
    tot = 0.0
    amp = 1.0
    norm = 0.0
    for i in range(octaves):
        k = 2 ** i
        tot = tot + amp * vnoise(w, h, cell * aspect / k, cell / k, seed + i * 17)
        norm += amp
        amp *= 0.5
    return tot / norm


def sd_rrect(X, Y, x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(X - cx) - hx
    qy = np.abs(Y - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def sd_circle(X, Y, cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def sd_seg(X, Y, ax, ay, bx, by):
    px, py = X - ax, Y - ay
    ux, uy = bx - ax, by - ay
    h = np.clip((px * ux + py * uy) / (ux * ux + uy * uy + 1e-9), 0, 1)
    return np.hypot(px - ux * h, py - uy * h)


def bevel(d, width, light=(-0.42, -0.9)):
    """Highlight and shade maps for a rounded edge of the shape whose distance field is d."""
    gy, gx = np.gradient(d)
    gx, gy = gx * S, gy * S
    k = gx * light[0] + gy * light[1]
    fall = smooth(width, 0.0, -d) * (d < 0)
    return np.clip(k, 0, 1) * fall, np.clip(-k, 0, 1) * fall


class Cv:
    """A straight-alpha float canvas at S times the final size."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h * S, w * S, 3), np.float32)
        self.a = np.zeros((h * S, w * S), np.float32)
        self.X, self.Y = grid(w, h)

    def paint(self, col, alpha, sl=None, atop=False):
        sl = sl or (slice(None), slice(None))
        A = self.a[sl]
        RGB = self.rgb[sl]
        a = np.clip(alpha, 0, 1).astype(np.float32)
        if atop:
            a = a * A
        col = np.asarray(col, np.float32)
        if col.ndim == 1:
            col = col[None, None, :]
        oa = a + A * (1 - a)
        new = (col * a[..., None] + RGB * (A * (1 - a))[..., None]) / np.maximum(oa, 1e-6)[..., None]
        RGB[:] = np.where(oa[..., None] > 1e-6, new, RGB)
        A[:] = oa

    def light(self, amount):
        self.rgb += (1 - self.rgb) * np.clip(amount, 0, 1)[..., None]

    def dark(self, amount):
        self.rgb *= (1 - np.clip(amount, 0, 1))[..., None]

    def warp(self, amp, cell, seed):
        """A small hand wobble over the whole drawing."""
        h, w = self.h, self.w
        dx = fbm(w, h, cell, seed, 2) * amp * S
        dy = fbm(w, h, cell, seed + 31, 2) * amp * S
        ys, xs = np.mgrid[0:h * S, 0:w * S].astype(np.float32)
        co = [ys + dy, xs + dx]
        pm = self.rgb * self.a[..., None]
        self.a = ndi.map_coordinates(self.a, co, order=1, mode="constant")
        pm = np.dstack([ndi.map_coordinates(pm[..., i], co, order=1, mode="constant") for i in range(3)])
        self.rgb = np.where(self.a[..., None] > 1e-5, pm / np.maximum(self.a, 1e-5)[..., None], 0)

    def image(self, white=False):
        h, w = self.h, self.w
        pm = (self.rgb * self.a[..., None]).reshape(h, S, w, S, 3).mean((1, 3))
        a = self.a.reshape(h, S, w, S).mean((1, 3))
        a = np.where(a < 0.6 / 255, 0, a)
        rgb = np.where(a[..., None] > 1e-4, pm / np.maximum(a, 1e-4)[..., None], 0)
        solid = a > 0
        if white and not solid.any():
            rgb[:] = 1
        elif not solid.all():
            # colour bleed: transparent pixels take the nearest drawn colour (no dark fringe in Roblox)
            idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
            rgb = rgb[idx[0], idx[1]]
        arr = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
        return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA")


class MaskDraw:
    """Pillow shapes in final-pixel coordinates, returned as a float mask at S times the size."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("L", (w * S, h * S), 0)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, v=255):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=v)

    def ell(self, x0, y0, x1, y1, v=255):
        self.d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=v)

    def circ(self, cx, cy, r, v=255):
        self.ell(cx - r, cy - r, cx + r, cy + r, v)

    def rect(self, x0, y0, x1, y1, r=0, v=255):
        self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=v)

    def line(self, pts, wd, v=255):
        ww = max(1, int(round(wd * S)))
        self.d.line([(x * S, y * S) for x, y in pts], fill=v, width=ww, joint="curve")
        for x, y in (pts[0], pts[-1]):
            self.circ(x, y, wd / 2, v)

    def arr(self, soft=0.0):
        a = np.asarray(self.im, np.float32) / 255
        if soft > 0:
            a = np.clip((blur(a, soft) - 0.5) * (2.5 * soft * S) + 0.5, 0, 1)
        return a


def curve(pts, n=24):
    """A smooth polyline through the points (Catmull-Rom)."""
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = (np.array(q, float) for q in p[i - 1:i + 3])
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                   + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(tuple(pts[-1]))
    return out


def outside_dist(mask):
    """Distance in final pixels from each point outside the mask to the mask."""
    return ndi.distance_transform_edt(mask < 0.5).astype(np.float32) / S


def drop_shadow(cv, mask, dx, dy, soft, alpha, col=(0.07, 0.05, 0.03)):
    sh = ndi.shift(mask, (dy * S, dx * S), order=1, mode="constant")
    cv.paint(col, alpha * blur(sh, soft))


# ----------------------------------------------------------------------------- surfaces

def paper_rgb(w, h, seed, base=PAPER, flecks=260, amp=1.0):
    r = np.random.default_rng(seed)
    v = 1 + amp * 0.014 * fbm(w, h, 52, seed, 2)
    dark = MaskDraw(w, h)
    lite = MaskDraw(w, h)
    for i in range(flecks):
        x, y = r.random() * w, r.random() * h
        ang = r.random() * np.pi
        ln = 2 + r.random() * 6
        md = dark if i % 2 else lite
        md.d.line([(x * S, y * S), ((x + np.cos(ang) * ln) * S, (y + np.sin(ang) * ln) * S)], fill=255, width=2)
    fl = blur(lite.arr(), 0.3) - blur(dark.arr(), 0.3)
    v = v + amp * 0.022 * fl
    return c(base)[None, None, :] * v[..., None]


def grid(w, h):
    ys, xs = np.mgrid[0:h * S, 0:w * S]
    return ((xs + 0.5) / S).astype(np.float32), ((ys + 0.5) / S).astype(np.float32)


def threads(n, r):
    """One value per half pixel, smoothed: the uneven threads of a weave (survives stretching)."""
    t = ndi.gaussian_filter1d(r.random(n * 2), 0.6)
    t = np.interp(np.linspace(0, n * 2 - 1, n * S), np.arange(n * 2), t)
    return ((t - t.mean()) / (t.std() + 1e-6)).astype(np.float32)


def canvas_rgb(w, h, seed, base=CANVAS):
    r = np.random.default_rng(seed)
    X, Y = grid(w, h)
    weave = np.sin(2 * np.pi * X / 3.0) * np.sin(2 * np.pi * Y / 3.0)
    rows, cols = threads(h, r), threads(w, r)
    v = 1 + 0.020 * weave + 0.009 * rows[:, None] + 0.009 * cols[None, :] + 0.022 * fbm(w, h, 60, seed + 3, 2)
    return c(base)[None, None, :] * v[..., None]


def leather_rgb(w, h, seed, base=LEATHER, amp=1.0):
    n1 = fbm(w, h, 48, seed, 3)
    n2 = fbm(w, h, 3.4, seed + 5, 2)
    n3 = fbm(w, h, 11, seed + 9, 2)
    v = 1 + amp * (0.07 * n1 + 0.018 * n3 - 0.04 * np.abs(n2) + 0.013)
    col = c(base)[None, None, :] * v[..., None]
    col[..., 0] *= 1 + 0.02 * n1  # warmer where it is lighter
    return col


def wood_rgb(w, h, seed, horizontal=True, base=WOOD):
    asp = 14.0
    if horizontal:
        g = fbm(w, h, 2.6, seed, 2, aspect=asp)
        warp = fbm(w, h, 40, seed + 4, 2)
        lines = np.sin((grid(w, h)[1] + 2.5 * warp) * 2 * np.pi / 4.2 + 3 * warp)
    else:
        g = np.asarray(Image.fromarray(fbm(h, w, 2.6, seed, 2, aspect=asp)).transpose(Image.TRANSPOSE))
        warp = fbm(w, h, 40, seed + 4, 2)
        lines = np.sin((grid(w, h)[0] + 2.5 * warp) * 2 * np.pi / 4.2 + 3 * warp)
    v = 1 + 0.07 * g + 0.035 * lines + 0.03 * fbm(w, h, 50, seed + 8, 2)
    return c(base)[None, None, :] * v[..., None]


def brass_rgb(w, h, seed, base=BRASS, amp=1.0):
    r = np.random.default_rng(seed)
    rows = ndi.gaussian_filter1d(r.random(h * S), 0.8)
    rows = (rows - rows.mean()) / (rows.std() + 1e-6)
    v = 1 + amp * (0.012 * rows[:, None] + 0.02 * fbm(w, h, 44, seed + 2, 2))
    return c(base)[None, None, :] * v[..., None] * np.ones((1, w * S, 1), np.float32)


def stitch(cv, ax, ay, bx, by, thick=3.0, col=THREAD):
    pad = thick + 3
    x0 = max(0, int((min(ax, bx) - pad) * S))
    x1 = min(cv.w * S, int((max(ax, bx) + pad) * S) + 1)
    y0 = max(0, int((min(ay, by) - pad) * S))
    y1 = min(cv.h * S, int((max(ay, by) + pad) * S) + 1)
    sl = (slice(y0, y1), slice(x0, x1))
    X, Y = cv.X[sl], cv.Y[sl]
    for px, py in ((ax, ay), (bx, by)):  # needle holes
        cv.paint((0.10, 0.07, 0.05), 0.6 * cov(sd_circle(X, Y, px, py, thick * 0.62)), sl, atop=True)
    d = sd_seg(X, Y, ax + 0.5, ay + 1.0, bx + 0.5, by + 1.0) - thick / 2
    cv.paint((0.05, 0.03, 0.02), 0.38 * smooth(1.2, -0.5, d), sl, atop=True)
    d = sd_seg(X, Y, ax, ay, bx, by) - thick / 2
    t = np.clip(-d / (thick / 2), 0, 1)
    cv.paint(c(col)[None, None, :] * (0.78 + 0.26 * t[..., None]), cov(d), sl, atop=True)


def stitch_run(cv, pts, length=8.5, gap=4.5, thick=3.0, seed=0, col=THREAD):
    """Stitches along a polyline, whole stitches only."""
    r = np.random.default_rng(seed)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        seg = np.hypot(bx - ax, by - ay)
        ux, uy = (bx - ax) / seg, (by - ay) / seg
        n = int((seg + gap) // (length + gap))
        slack = (seg - (n * length + (n - 1) * gap)) / 2
        for i in range(n):
            s0 = slack + i * (length + gap)
            j = (r.random(4) - 0.5) * 0.7
            stitch(cv, ax + ux * s0 + j[0], ay + uy * s0 + j[1],
                   ax + ux * (s0 + length) + j[2], ay + uy * (s0 + length) + j[3], thick, col)


# ----------------------------------------------------------------------------- shared motif: the fish

def fish_mask(w, h, cx, cy, L, fin=0.25, soft=None):
    """An original, plain fish silhouette, head to the right. Returns (body mask, eye centre, eye radius)."""
    m = MaskDraw(w, h)
    hh = 0.17 * L
    m.ell(cx - 0.20 * L, cy - hh, cx + 0.50 * L, cy + hh)
    m.poly([(cx - 0.02 * L, cy - 0.155 * L), (cx - 0.31 * L, cy - 0.045 * L), (cx - 0.31 * L, cy + 0.045 * L),
            (cx - 0.02 * L, cy + 0.155 * L)])
    m.poly([(cx - 0.27 * L, cy), (cx - 0.50 * L, cy - 0.20 * L), (cx - 0.41 * L, cy), (cx - 0.50 * L, cy + 0.20 * L)])
    m.poly([(cx + 0.17 * L, cy - 0.15 * L), (cx - 0.01 * L, cy - fin * L), (cx - 0.14 * L, cy - 0.11 * L)])
    m.poly([(cx + 0.05 * L, cy + 0.15 * L), (cx - 0.05 * L, cy + (fin - 0.02) * L), (cx - 0.13 * L, cy + 0.11 * L)])
    return m.arr(soft if soft is not None else 0.022 * L), (cx + 0.36 * L, cy - 0.045 * L), 0.032 * L


# ----------------------------------------------------------------------------- 1 to 3: panels

def paper_card():
    cv = Cv(256, 256)
    X, Y = cv.X, cv.Y
    wob = 1.0 * fbm(256, 256, 20, 11, 2) + 0.55 * fbm(256, 256, 4.5, 12, 2)
    d = sd_rrect(X, Y, 9, 7, 247, 244, 4) + wob
    drop_shadow(cv, cov(d), 0, 3.0, 3.2, 0.42)
    rgb = paper_rgb(256, 256, 13)
    edge = smooth(16, 0, -d)  # aged toward the edge
    rgb = rgb * (1 - edge[..., None] * np.array([0.05, 0.065, 0.10], np.float32))
    cv.paint(rgb, cov(d))
    hi, lo = bevel(d, 1.6)
    cv.light(0.30 * hi)
    cv.dark(0.20 * lo)
    cv.paint(c((120, 100, 70)), 0.30 * smooth(1.0, 0.0, np.abs(d + 0.2)), atop=True)  # the cut edge
    return cv.image()


def canvas_panel():
    cv = Cv(256, 256)
    X, Y = cv.X, cv.Y
    d = sd_rrect(X, Y, 8, 6, 248, 244, 9) + 0.45 * fbm(256, 256, 14, 21, 2)
    drop_shadow(cv, cov(d), 0, 3.0, 3.2, 0.42)
    rgb = canvas_rgb(256, 256, 22)
    hem = 12.0
    band = smooth(-hem - 0.6, -hem + 0.6, d)  # 1 on the hem, 0 inside
    rgb = rgb * (1 - 0.085 * band[..., None])
    cv.paint(rgb, cov(d))
    # the fold of the hem: a shade line with a light lip, continuous so it survives stretching
    cv.paint((0.20, 0.15, 0.09), 0.34 * smooth(1.1, 0.0, np.abs(d + hem + 0.7)), atop=True)
    cv.light(0.12 * smooth(1.0, 0.0, np.abs(d + hem - 0.7)) * (d < 0))
    # a thread line down the middle of the hem (continuous, reads as topstitching at phone size)
    cv.paint(c(THREAD), 0.32 * smooth(0.9, 0.2, np.abs(d + hem / 2)), atop=True)
    hi, lo = bevel(d, 2.2)
    cv.light(0.22 * hi)
    cv.dark(0.24 * lo)
    # leather corners, stitched along the diagonal
    lea = leather_rgb(256, 256, 23)
    leg = 56.0
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ox, oy = (8 if sx > 0 else 248), (6 if sy > 0 else 244)
        u = (X - ox) * sx
        v = (Y - oy) * sy
        dl = (u + v - leg) / np.sqrt(2)  # negative on the corner side of the diagonal
        dp = np.maximum(d, dl)
        cv.paint((0.10, 0.07, 0.04), 0.40 * smooth(3.5, 0.0, dl) * (dl > 0), atop=True)  # shadow on the canvas
        cv.paint(lea * (0.86 + 0.14 * smooth(0, 7, -dp))[..., None], cov(dp) * cov(d))
        h2, l2 = bevel(dp, 2.4)
        cv.light(0.30 * h2 * cov(dp))
        cv.dark(0.28 * l2 * cov(dp))
        ins = 6.5  # stitches sit this far inside the diagonal
        a = (ox + sx * (leg - ins * np.sqrt(2) - 7), oy + sy * 7)
        b = (ox + sx * 7, oy + sy * (leg - ins * np.sqrt(2) - 7))
        stitch_run(cv, [a, b], 8.5, 4.5, 3.0, seed=30 + sx + 3 * sy)
    return cv.image()


def leather_panel():
    cv = Cv(256, 256)
    X, Y = cv.X, cv.Y
    d = sd_rrect(X, Y, 8, 6, 248, 244, 14) + 0.4 * fbm(256, 256, 16, 41, 2)
    drop_shadow(cv, cov(d), 0, 3.0, 3.2, 0.45)
    rgb = leather_rgb(256, 256, 42)
    rgb = rgb * (0.80 + 0.20 * smooth(0, 20, -d))[..., None]  # burnished edge
    cv.paint(rgb, cov(d))
    hi, lo = bevel(d, 3.0)
    cv.light(0.26 * hi)
    cv.dark(0.34 * lo)
    # a creased line all the way round (continuous), and the stitch channel
    cv.paint((0.10, 0.06, 0.03), 0.42 * smooth(1.0, 0.1, np.abs(d + 8.0)), atop=True)
    cv.light(0.10 * smooth(0.9, 0.0, np.abs(d + 9.3)) * (d < 0))
    cv.paint((0.10, 0.06, 0.03), 0.16 * smooth(2.2, 0.4, np.abs(d + 16.0)), atop=True)
    # stitches turn each corner and stop before the stretch zone (SliceCenter 76..180)
    i0, i1 = 24.0, 232.0
    j0, j1 = 22.0, 228.0
    run = 46.0
    seed = 50
    for cx_, sx in ((i0, 1), (i1, -1)):
        for cy_, sy in ((j0, 1), (j1, -1)):
            stitch_run(cv, [(cx_ + sx * run, cy_), (cx_ + sx * 2.5, cy_)], 8.5, 4.5, 3.0, seed)
            stitch_run(cv, [(cx_, cy_ + sy * 2.5), (cx_, cy_ + sy * run)], 8.5, 4.5, 3.0, seed + 1)
            seed += 2
    return cv.image()


# ----------------------------------------------------------------------------- 4 to 7: buttons, tab, fight bar

def brass_button(pressed=False):
    cv = Cv(128, 64)
    X, Y = cv.X, cv.Y
    top = 7.0 if pressed else 3.0
    d_lip = sd_rrect(X, Y, 4, 8, 124, 58.5, 11)
    d = sd_rrect(X, Y, 4, top, 124, top + 50, 11)
    both = np.minimum(d, d_lip)
    if not pressed:
        drop_shadow(cv, cov(both), 0, 1.6, 1.2, 0.42)
    cv.paint(c((64, 44, 20)), 0.9 * cov(both - 1.1))  # dark keyline
    cv.paint(c((112, 80, 36)), cov(d_lip))  # the side of the plate
    rgb = brass_rgb(128, 64, 61, amp=0.7) * 1.05  # a touch lighter than plan brass so ink text clears 4.5 to 1
    g = (Y - top) / 50.0
    rgb = rgb * (1.05 - 0.06 * smooth(0.0, 1.0, g))[..., None]
    if pressed:
        rgb = rgb * 0.985
    cv.paint(rgb, cov(d))
    hi, lo = bevel(d, 3.0)
    face = cov(d)
    cv.light((0.16 if pressed else 0.42) * hi * face)
    cv.dark(0.26 * lo * face)
    if pressed:  # pushed in: a shade under the top edge
        cv.dark(0.22 * smooth(7.0, 0.0, -d) * smooth(0.55, 0.15, g) * face)
    return cv.image()


def tackle_tab():
    cv = Cv(128, 96)
    X, Y = cv.X, cv.Y
    d = sd_rrect(X, Y, -30, 8, 121, 85, 13) + 0.35 * fbm(128, 96, 12, 71, 2)
    d_lip = sd_rrect(X, Y, -30, 12, 121, 89, 13)
    both = np.minimum(d, d_lip)
    drop_shadow(cv, cov(both), 0.8, 1.8, 1.6, 0.42)
    cv.paint(c(INKBROWN), 0.75 * cov(both - 1.0))
    cv.paint(c((168, 150, 112)), cov(d_lip))  # card thickness
    rgb = paper_rgb(128, 96, 72, MANILA, flecks=90)
    rgb = rgb * (1 - smooth(12, 0, -d)[..., None] * np.array([0.04, 0.05, 0.08], np.float32))
    cv.paint(rgb, cov(d))
    hi, lo = bevel(d, 1.8)
    cv.light(0.30 * hi * cov(d))
    cv.dark(0.16 * lo * cov(d))
    # the box edge: a leather binding down the left, two brass rivets
    ds = sd_rrect(X, Y, -8, 2, 15, 94, 3.5)
    cv.paint((0.06, 0.04, 0.02), 0.45 * smooth(4.0, 0.0, ds) * (ds > 0), atop=True)
    cv.paint(c(INKBROWN), 0.8 * cov(ds - 1.0))
    lea = leather_rgb(128, 96, 73) * (0.84 + 0.16 * smooth(0, 6, -ds))[..., None]
    cv.paint(lea, cov(ds))
    h2, l2 = bevel(ds, 2.2)
    cv.light(0.24 * h2 * cov(ds))
    cv.dark(0.30 * l2 * cov(ds))
    for ry in (24.0, 72.0):
        dr = sd_circle(X, Y, 7.5, ry, 3.6)
        cv.paint(c((60, 42, 20)), 0.9 * cov(dr - 0.9))
        cv.paint(c(BRASS) * 1.05, cov(dr))
        h3, l3 = bevel(dr, 3.0)
        cv.light(0.55 * h3 * cov(dr))
        cv.dark(0.35 * l3 * cov(dr))
    return cv.image()


def fight_frame():
    cv = Cv(256, 64)
    X, Y = cv.X, cv.Y
    fx0, fy0, fx1, fy1 = 3.0, 2.0, 253.0, 59.0
    d_out = sd_rrect(X, Y, fx0, fy0, fx1, fy1, 7)
    d_in = sd_rrect(X, Y, fx0 + 13, fy0 + 13, fx1 - 13, fy1 - 13, 4)
    d = np.maximum(d_out, -d_in)
    drop_shadow(cv, cov(d_out), 0, 1.6, 1.2, 0.42)
    # the frame casts a soft shade into the window (drawn in alpha, sits over the track)
    inner = cov(d_in)
    cv.paint((0.02, 0.03, 0.05), 0.50 * smooth(5.5, 0.0, -d_in) * inner * (0.55 + 0.45 * smooth(fy1 - 13, fy0 + 13, Y)))
    cv.paint(c((46, 32, 20)), 0.9 * cov(d_out - 1.0) * (1 - inner))
    horiz = wood_rgb(256, 64, 81, True)
    vert = wood_rgb(256, 64, 82, False)
    to_tb = np.minimum(Y - fy0, fy1 - Y)
    to_lr = np.minimum(X - fx0, fx1 - X)
    mitre = smooth(-0.5, 0.5, to_lr - to_tb)  # 1 on the top and bottom rails
    rgb = horiz * mitre[..., None] + vert * (1 - mitre[..., None])
    cv.paint(rgb, cov(d))
    hi, lo = bevel(d_out, 3.0)
    fr = cov(d)
    cv.light(0.22 * hi * fr)
    cv.dark(0.30 * lo * fr)
    # a brass liner round the window
    liner = cov(d_in - 2.2) * (1 - inner)
    cv.paint(c(BRASS) * 1.04, liner)
    h2, l2 = bevel(-d_in + 2.2, 2.2)
    cv.light(0.40 * h2 * liner)
    cv.dark(0.40 * l2 * liner)
    cv.paint(c((50, 34, 18)), 0.6 * smooth(0.8, 0.0, np.abs(d_in - 2.4)) * (1 - inner))
    cv.paint(c((40, 26, 14)), 0.7 * smooth(0.7, 0.0, np.abs(d_in)) )
    # brass corner caps
    brass = brass_rgb(256, 64, 83)
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ox, oy = (fx0 if sx > 0 else fx1), (fy0 if sy > 0 else fy1)
        u, v = (X - ox) * sx, (Y - oy) * sy
        dl = (u + v - 23.0) / np.sqrt(2)
        dc = np.maximum(np.maximum(d_out, dl), -(d_in - 2.2))
        cv.paint(c((56, 38, 18)), 0.85 * cov(dc - 0.9) * fr)
        cv.paint(brass * 1.03, cov(dc))
        h3, l3 = bevel(dc, 2.4)
        cv.light(0.45 * h3 * cov(dc))
        cv.dark(0.32 * l3 * cov(dc))
        dr = sd_circle(X, Y, ox + sx * 6.6, oy + sy * 6.6, 1.5)
        cv.paint(c((70, 48, 22)), 0.85 * cov(dr), atop=True)
        cv.light(0.5 * cov(sd_circle(X, Y, ox + sx * 6.6 - 0.4, oy + sy * 6.6 - 0.5, 0.6)))
    return cv.image()


def water_track():
    cv = Cv(256, 32)
    X, Y = cv.X, cv.Y
    d = sd_rrect(X, Y, 0, 0, 256, 32, 7)
    col = c(WATER)[None, None, :] * np.ones((32 * S, 256 * S, 1), np.float32)
    col = col * (1 + 0.012 * fbm(256, 32, 60, 91, 2))[..., None]
    cv.paint(col, cov(d))
    cv.dark(0.42 * smooth(7.0, 0.0, -d) * smooth(26, 4, Y))      # shade under the top edge
    cv.dark(0.16 * smooth(4.0, 0.0, -d))
    cv.light(0.16 * smooth(3.0, 0.0, -d) * smooth(18, 30, Y) * (d < 0))  # a glint along the bottom
    cv.paint(c((14, 34, 48)), 0.85 * smooth(1.2, 0.2, np.abs(d + 0.6)), atop=True)
    return cv.image()


# ----------------------------------------------------------------------------- 8 to 10, 12: tintable marks, tag, ruler

def fish_marker():
    cv = Cv(64, 32)
    m, eye, er = fish_mask(64, 32, 32, 16, 58, fin=0.235)
    od = outside_dist(m)
    cv.paint((0.24, 0.24, 0.24), np.clip((1.3 - od) * S + 0.5, 0, 1))  # darker rim of the same tint
    cv.paint((1, 1, 1), m)
    cv.paint((0.24, 0.24, 0.24), cov(sd_circle(cv.X, cv.Y, eye[0], eye[1], er + 0.5)))
    return cv.image(white=True)


def rarity_seal():
    cv = Cv(128, 128)
    X, Y = cv.X, cv.Y
    wob = 2.0 * fbm(128, 128, 15, 101, 2) + 0.9 * fbm(128, 128, 4, 102, 2)
    r = np.hypot(X - 64, Y - 64)
    outer = cov(r - 57 + wob)
    gap = cov(np.abs(r - 43.5 + 0.5 * wob) - 1.9)
    a = outer * (1 - gap)
    # the fish and two water lines, left as bare paper
    m, eye, er = fish_mask(128, 128, 65, 58, 54, fin=0.25)
    wl = MaskDraw(128, 128)
    for yy, x0, x1 in ((82, 38, 90), (92, 48, 80)):
        pts = [(x, yy + 1.8 * np.sin((x - x0) / 5.2)) for x in np.linspace(x0, x1, 40)]
        wl.line(pts, 3.2)
    knock = np.maximum(m, wl.arr(0.5))
    a = a * (1 - knock)
    a = np.maximum(a, cov(sd_circle(X, Y, eye[0], eye[1], er + 0.4)))
    # uneven inking: a patchy side and small dropouts
    patch = smooth(-0.1, 0.5, fbm(128, 128, 40, 103, 2))
    speck = smooth(0.38, 0.54, fbm(128, 128, 2.6, 104, 2)) * (0.25 + 0.75 * patch)
    dens = 0.90 + 0.10 * smooth(-0.4, 0.4, fbm(128, 128, 22, 105, 2))
    a = a * (1 - 0.6 * speck) * dens
    cv.paint((1, 1, 1), a)
    return cv.image(white=True)


def rarity_ribbon():
    cv = Cv(128, 32)
    X, Y = cv.X, cv.Y
    tails = MaskDraw(128, 32)
    tails.poly([(1.5, 9), (24, 9), (24, 30.5), (1.5, 30.5), (9, 19.75)])
    tails.poly([(126.5, 9), (104, 9), (104, 30.5), (126.5, 30.5), (119, 19.75)])
    cv.paint((0.70, 0.70, 0.70), tails.arr(0.35))
    folds = MaskDraw(128, 32)
    folds.poly([(15, 25.5), (24, 25.5), (24, 30.5)])
    folds.poly([(113, 25.5), (104, 25.5), (104, 30.5)])
    cv.paint((0.46, 0.46, 0.46), folds.arr(0.25))
    d = sd_rrect(X, Y, 15, 2, 113, 25.5, 1.5)
    g = (Y - 2) / 23.5
    v = 1.0 - 0.07 * smooth(0.55, 1.0, g) - 0.05 * smooth(8, 0, X - 15) - 0.05 * smooth(8, 0, 113 - X)
    cv.paint(np.dstack([v, v, v]), cov(d))
    for yy in (4.6, 22.9):  # woven edge lines
        cv.dark(0.16 * smooth(0.7, 0.1, np.abs(Y - yy)) * cov(d))
    return cv.image(white=True)


def weight_tag():
    cv = Cv(96, 128)
    X, Y = cv.X, cv.Y
    shape = MaskDraw(96, 128)
    shape.poly([(15, 47), (29, 31), (67, 31), (81, 47), (81, 121), (15, 121)])
    m = shape.arr(1.6)
    hole = cov(sd_circle(X, Y, 48, 44, 3.1))
    # the twine: one strand behind the tag, drawn first
    back = MaskDraw(96, 128)
    back.line(curve([(51.5, 0), (52.5, 16), (50.5, 32), (48.5, 43)]), 2.6)
    bm = back.arr(0.3)
    cv.paint(c(INKBROWN), 0.8 * np.clip((0.8 - outside_dist(bm)) * S + 0.5, 0, 1))
    cv.paint(c((176, 150, 104)), bm)
    drop_shadow(cv, m, 0.8, 1.8, 1.7, 0.40)
    od = outside_dist(m)
    cv.paint(c((60, 42, 20)), 0.85 * np.clip((0.9 - od) * S + 0.5, 0, 1))
    cv.paint(brass_rgb(96, 128, 111) * 1.02, m)  # the brass edge
    inner_d = ndi.distance_transform_edt(m > 0.5).astype(np.float32) / S
    rim = 3.4
    pm = np.clip((inner_d - rim) * S + 0.5, 0, 1)
    edge_l = smooth(rim, 0, inner_d)
    cv.light(0.35 * edge_l * smooth(60, 30, Y) * m)
    cv.dark(0.25 * edge_l * smooth(90, 121, Y) * m)
    cv.paint(c((84, 60, 28)), 0.55 * np.clip(1 - np.abs(inner_d - rim) * S * 0.5, 0, 1) * m)
    rgb = paper_rgb(96, 128, 112, PAPER, flecks=70)
    rgb = rgb * (1 - smooth(rim + 9, rim, inner_d)[..., None] * np.array([0.03, 0.04, 0.07], np.float32))
    cv.paint(rgb, pm)
    # eyelet
    de = sd_circle(X, Y, 48, 44, 6.6)
    cv.paint(c((60, 42, 20)), 0.85 * cov(de - 0.9))
    cv.paint(c(BRASS) * 1.06, cov(de))
    h3, l3 = bevel(de, 3.0)
    cv.light(0.5 * h3 * cov(de))
    cv.dark(0.3 * l3 * cov(de))
    cv.paint(c((40, 28, 16)), cov(sd_circle(X, Y, 48, 44, 3.9)))
    cv.a = cv.a * (1 - hole)  # see-through hole
    # the front strand, through the hole and up
    front = MaskDraw(96, 128)
    front.line(curve([(44.5, 0), (43.5, 14), (45.5, 30), (47.6, 44)]), 2.6)
    fm = front.arr(0.3)
    cv.paint(c(INKBROWN), 0.8 * np.clip((0.8 - outside_dist(fm)) * S + 0.5, 0, 1))
    tw = c((204, 178, 128))[None, None, :] * (1 + 0.10 * np.sin((X * 0.6 + Y) * 2.2))[..., None]
    cv.paint(tw, fm)
    return cv.image()


def ruler_strip():
    """White, tintable, tiles every 256 px: a long tick every 32 px, a mid tick every 16, a short one every 8."""
    cv = Cv(256, 32)
    X, Y = cv.X, cv.Y
    r = np.random.default_rng(121)
    a = cov(np.abs(Y - 6.0) - 1.0) * 0.96
    for k in range(32):
        x = 1.0 + 8 * k
        if k % 4 == 0:
            ln, wd = 17.0, 2.0
        elif k % 2 == 0:
            ln, wd = 11.5, 1.6
        else:
            ln, wd = 7.0, 1.4
        ln += (r.random() - 0.5) * 1.2
        x += (r.random() - 0.5) * 0.3 if k else 0.0
        d = sd_seg(X, Y, x, 6.0, x + (r.random() - 0.5) * 0.4, 6.0 + ln) - wd / 2
        a = np.maximum(a, cov(d) * (0.90 + 0.08 * r.random()))
    cv.paint((1, 1, 1), a)
    return cv.image(white=True)


def stitch_strip():
    """White, tintable, tiles every 64 px along x (rotate the label 90 degrees for an upright edge)."""
    cv = Cv(64, 12)
    X, Y = cv.X, cv.Y
    r = np.random.default_rng(131)
    for k in range(4):
        x0 = 3.0 + 16 * k
        y0, y1 = 6.0 + (r.random() - 0.5) * 0.8, 6.0 + (r.random() - 0.5) * 0.8
        for px, py in ((x0, y0), (x0 + 10, y1)):
            cv.paint((0.2, 0.2, 0.2), 0.55 * cov(sd_circle(X, Y, px, py, 1.9)))
        d = sd_seg(X, Y, x0, y0, x0 + 10, y1) - 1.5
        t = np.clip(-d / 1.5, 0, 1)
        v = 0.80 + 0.20 * t
        cv.paint(np.dstack([v, v, v]), cov(d))
    return cv.image(white=True)


# ----------------------------------------------------------------------------- 11: icons

def _finish_icon(cv, seed, grain=0.03):
    cv.rgb *= (1 + grain * fbm(cv.w, cv.h, 7, seed, 2))[..., None]
    cv.warp(0.45, 15, seed + 1)
    return cv.image()


def _outline(cv, union, width=1.5, alpha=0.95):
    od = outside_dist(union)
    cv.paint(c(INKBROWN), alpha * np.clip((width - od) * S + 0.5, 0, 1))


def icon_coin():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    d = sd_circle(X, Y, 32, 32, 26.5)
    _outline(cv, cov(d), 1.6)
    cv.paint(c(BRASS) * 1.10, cov(d))
    d2 = sd_circle(X, Y, 32, 32, 21.0)
    cv.paint(c(BRASS) * 0.93, cov(d2))
    cv.paint(c((84, 58, 26)), 0.75 * smooth(0.9, 0.1, np.abs(d2)))
    m, eye, er = fish_mask(64, 64, 32.5, 32.5, 31, fin=0.25)
    sh = ndi.shift(m, (1.1 * S, 0.8 * S), order=1)
    cv.paint(c((96, 68, 30)), 0.65 * sh * cov(d2))
    cv.paint(c((226, 190, 118)), m)
    cv.paint(c((96, 68, 30)), cov(sd_circle(X, Y, eye[0], eye[1], er + 0.5)))
    hi, lo = bevel(d, 5.5)
    cv.light(0.50 * hi * cov(d))
    cv.dark(0.34 * lo * cov(d))
    return _finish_icon(cv, 201, 0.02)


def icon_creel():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    body = MaskDraw(64, 64)
    body.poly([(9, 29), (55, 29), (51.5, 56), (12.5, 56)])
    bm = body.arr(2.2)
    lid = MaskDraw(64, 64)
    lid.d.chord([7 * S, 15 * S, 57 * S, 45 * S], 180, 360, fill=255)
    lm = lid.arr(1.2)
    handle = MaskDraw(64, 64)
    handle.line(curve([(14, 24), (18, 10), (32, 5.5), (46, 10), (50, 24)]), 3.4)
    hm = handle.arr(0.4) * (1 - lm)
    strap = MaskDraw(64, 64)
    strap.rect(28, 21, 36, 44, r=1.5)
    sm = strap.arr(0.4)
    union = np.maximum.reduce([bm, lm, hm, sm])
    _outline(cv, union, 1.5)
    cv.paint(c((112, 72, 44)), hm)
    wick = c((200, 164, 104))
    cv.paint(wick[None, None, :] * (1.04 - 0.16 * smooth(30, 58, Y))[..., None], bm)
    # the weave: bands with staggered stakes
    wv = MaskDraw(64, 64)
    for i, yy in enumerate(np.arange(34.5, 56, 5.4)):
        wv.line([(8, yy), (56, yy)], 1.1)
    for i, y0 in enumerate(np.arange(29.5, 56, 5.4)):
        for xx in np.arange(12 + (i % 2) * 3.5, 54, 7.0):
            wv.line([(xx, y0 + 0.6), (xx, y0 + 4.6)], 1.1)
    cv.paint(c((128, 94, 52)), 0.62 * wv.arr(0.2) * bm)
    cv.paint(c((214, 180, 120))[None, None, :] * (1.06 - 0.10 * smooth(16, 30, Y))[..., None], lm)
    lw = MaskDraw(64, 64)
    lw.line(curve([(11, 27), (20, 20.5), (32, 18.5), (44, 20.5), (53, 27)]), 1.0)
    cv.paint(c((128, 94, 52)), 0.5 * lw.arr(0.2) * lm)
    cv.paint(c(INKBROWN), 0.85 * smooth(1.0, 0.2, np.abs(Y - 29.6)) * np.maximum(bm, lm))  # the lid line
    hole = MaskDraw(64, 64)
    hole.rect(41, 20.5, 50, 25.5, r=1.6)
    cv.paint(c((58, 40, 26)), hole.arr(0.3) * lm)
    cv.paint(c(INKBROWN), 0.9 * np.clip((1.0 - outside_dist(sm)) * S + 0.5, 0, 1) * union)
    cv.paint(c((120, 76, 46)), sm)
    bk = cov(np.abs(sd_rrect(X, Y, 27.2, 33.5, 36.8, 40.5, 1.2)) - 0.9)
    cv.paint(c(BRASS) * 1.15, bk)
    return _finish_icon(cv, 211)


def icon_dial():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    d = sd_circle(X, Y, 32, 32, 28.0)
    _outline(cv, cov(d), 1.6)
    cv.paint(c(BRASS) * 1.06, cov(d))
    hi, lo = bevel(d, 5.0)
    cv.light(0.45 * hi * cov(d))
    cv.dark(0.34 * lo * cov(d))
    d2 = sd_circle(X, Y, 32, 32, 23.2)
    face = cov(d2)
    day = c((240, 224, 170))[None, None, :] * (1.0 - 0.05 * smooth(12, 32, Y))[..., None]
    night = c((44, 58, 96))[None, None, :] * (1.0 + 0.16 * smooth(56, 32, Y))[..., None]
    split = smooth(31.6, 32.4, Y)
    cv.paint(day * (1 - split[..., None]) + night * split[..., None], face)
    cv.paint(c((70, 48, 22)), 0.8 * smooth(0.9, 0.1, np.abs(d2)))
    cv.paint(c(INKBROWN), 0.75 * smooth(0.8, 0.2, np.abs(Y - 32)) * face)
    # sun
    sun = MaskDraw(64, 64)
    for k in range(8):
        ang = k * np.pi / 4 + np.pi / 8
        sun.line([(32 + 7.4 * np.cos(ang), 19.5 + 7.4 * np.sin(ang)), (32 + 10.2 * np.cos(ang), 19.5 + 10.2 * np.sin(ang))], 1.7)
    rays = sun.arr(0.2) * face * (Y < 31)
    cv.paint(c((214, 132, 40)), rays)
    ds = sd_circle(X, Y, 32, 19.5, 5.3)
    cv.paint(c((150, 86, 24)), 0.9 * cov(ds - 0.8) * face)
    cv.paint(c((244, 176, 60)), cov(ds))
    # moon and stars
    moon = cov(sd_circle(X, Y, 32, 45, 5.6)) * (1 - cov(sd_circle(X, Y, 35.2, 43.4, 4.9)))
    cv.paint(c((244, 236, 210)), moon)
    for sx, sy, sr in ((21.5, 41, 1.15), (43.5, 46.5, 1.0), (38.5, 51.5, 0.8), (24, 50, 0.8)):
        cv.paint(c((244, 236, 210)), cov(sd_circle(X, Y, sx, sy, sr)) * face)
    # quarter marks on the rim
    for ang in (0, np.pi / 2, np.pi, 3 * np.pi / 2):
        px, py = 32 + 25.6 * np.cos(ang), 32 + 25.6 * np.sin(ang)
        cv.paint(c((70, 48, 22)), 0.85 * cov(sd_circle(X, Y, px, py, 1.25)))
    return _finish_icon(cv, 221, 0.02)


def icon_dial_hand():
    """The hand for the dial, pointing up; the code turns it about the centre of the image."""
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    hand = MaskDraw(64, 64)
    hand.poly([(32, 9.5), (34.3, 16.5), (33.0, 16.5), (33.1, 37), (30.9, 37), (31.0, 16.5), (29.7, 16.5)])
    hm = hand.arr(0.35)
    hub = cov(sd_circle(X, Y, 32, 32, 3.2))
    union = np.maximum(hm, hub)
    od = outside_dist(union)
    cv.paint(c((244, 236, 210)), 0.9 * np.clip((1.9 - od) * S + 0.5, 0, 1))  # a pale halo so it shows on the night half
    cv.paint(c(INKBROWN), np.clip((1.1 - od) * S + 0.5, 0, 1))
    cv.paint(c((176, 50, 38)), hm)
    cv.paint(c(BRASS) * 1.1, hub)
    cv.paint(c(INKBROWN), cov(sd_circle(X, Y, 32, 32, 1.1)))
    return cv.image()


def _rot(pts, ang, cx=32.0, cy=32.0):
    ca, sa = np.cos(ang), np.sin(ang)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]


def icon_journal():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    ang = np.radians(-7)
    R = lambda pts: _rot(pts, ang)
    box = lambda x0, y0, x1, y1: R([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    pages = MaskDraw(64, 64)
    pages.poly(box(17, 10.5, 54, 58))
    pm = pages.arr(1.0)
    cover = MaskDraw(64, 64)
    cover.poly(box(12, 7, 50.5, 54.5))
    cm = cover.arr(1.6)
    rib = MaskDraw(64, 64)
    rib.poly(R([(37, 52), (42.5, 52), (42.5, 60.5), (39.75, 57.8), (37, 60.5)]))
    rm = rib.arr(0.3)
    union = np.maximum.reduce([pm, cm, rm])
    _outline(cv, union, 1.5)
    cv.paint(c((178, 50, 40)), rm)
    cv.paint(c((238, 230, 206)), pm)
    pl = MaskDraw(64, 64)
    for off in (1.6, 3.2):
        pl.line(R([(51.5 + off * 0.0, 12 + off), (52.2 + off * 0.55, 56.6)]), 0.7)
        pl.line(R([(18, 55.2 + off * 0.75), (52.6, 55.2 + off * 0.75)]), 0.7)
    cv.paint(c((150, 136, 108)), 0.75 * pl.arr(0.15) * pm * (1 - cm))
    cv.paint(c(INKBROWN), 0.9 * np.clip((1.0 - outside_dist(cm)) * S + 0.5, 0, 1) * union)
    green = c((58, 92, 74))
    cv.paint(green[None, None, :] * (1.08 - 0.16 * smooth(8, 56, Y))[..., None], cm)
    spine = MaskDraw(64, 64)
    spine.poly(box(12, 7, 19.5, 54.5))
    cv.paint(c((40, 64, 52)), spine.arr(0.3) * cm)
    bands = MaskDraw(64, 64)
    bands.line(R([(12.5, 14), (19.3, 14)]), 1.6)
    bands.line(R([(12.5, 47.5), (19.3, 47.5)]), 1.6)
    cv.paint(c(BRASS) * 1.15, bands.arr(0.15) * cm)
    label = MaskDraw(64, 64)
    label.poly(box(24, 14.5, 46.5, 33.5))
    lm = label.arr(0.9)
    cv.paint(c(INKBROWN), 0.85 * np.clip((0.9 - outside_dist(lm)) * S + 0.5, 0, 1) * cm)
    cv.paint(c(PAPER), lm)
    fm, eye, er = fish_mask(64, 64, 35.4, 23.2, 17.5, fin=0.25, soft=0.3)
    fm = ndi.rotate(fm, 7, reshape=False, order=1)
    cv.paint(c(INKBROWN), 0.92 * fm * lm)
    tl = MaskDraw(64, 64)
    tl.line(R([(26, 40.5), (44.5, 40.5)]), 1.7)
    tl.line(R([(29.5, 45.5), (41, 45.5)]), 1.4)
    cv.paint(c((214, 196, 140)), 0.85 * tl.arr(0.15) * cm)
    return _finish_icon(cv, 231)


def icon_goals():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    ang = np.radians(5)
    R = lambda pts: _rot(pts, ang)
    note = MaskDraw(64, 64)
    note.poly(R([(11, 9), (53, 9), (53, 49), (44, 58), (11, 58)]))
    nm = note.arr(1.0)
    fold = MaskDraw(64, 64)
    fold.poly(R([(53, 49), (44, 58), (44, 49)]))
    fm = fold.arr(0.4)
    pin = cov(sd_circle(X, Y, 33.2, 9.6, 4.6))
    union = np.maximum(nm, pin)
    _outline(cv, union, 1.5)
    rgb = c(PAPER)[None, None, :] * (1.03 - 0.07 * smooth(8, 58, Y))[..., None]
    cv.paint(rgb, nm)
    cv.paint(c((198, 184, 150)), fm)
    cv.paint(c(INKBROWN), 0.8 * np.clip((0.8 - outside_dist(fm)) * S + 0.5, 0, 1) * nm)
    rows = (20.5, 32.0, 43.5)
    boxes = MaskDraw(64, 64)
    lines = MaskDraw(64, 64)
    for i, yy in enumerate(rows):
        b = R([(16.5, yy - 3.6), (23.7, yy - 3.6), (23.7, yy + 3.6), (16.5, yy + 3.6)])
        boxes.line(b + [b[0]], 1.35)
        lines.line(R([(28.5, yy), (47.5 - (5 if i == 1 else 0) - (9 if i == 2 else 0), yy)]), 2.0)
    cv.paint(c(INKBROWN), 0.92 * boxes.arr(0.15) * nm)
    cv.paint(c((96, 86, 72)), 0.85 * lines.arr(0.2) * nm)
    chk = MaskDraw(64, 64)
    for yy in rows[:2]:
        chk.line(R([(17.2, yy - 0.6), (20.0, yy + 2.6), (26.0, yy - 5.4)]), 2.3)
    km = chk.arr(0.25)
    cv.paint(c(INKBROWN), 0.55 * np.clip((0.7 - outside_dist(km)) * S + 0.5, 0, 1) * nm)
    cv.paint(c((52, 128, 76)), km)
    dp = sd_circle(X, Y, 33.2, 9.6, 4.6)
    cv.paint(c((60, 42, 20)), 0.9 * cov(dp - 1.2))
    cv.paint(c(BRASS) * 1.08, cov(dp))
    h3, l3 = bevel(dp, 4.0)
    cv.light(0.55 * h3 * cov(dp))
    cv.dark(0.35 * l3 * cov(dp))
    return _finish_icon(cv, 241)


def icon_bait():
    cv = Cv(64, 64)
    X, Y = cv.X, cv.Y
    can = MaskDraw(64, 64)
    can.rect(13, 30, 51, 54)
    can.ell(13, 47, 51, 61)
    can.ell(13, 23, 51, 37)
    km = can.arr(0.5)
    worm = MaskDraw(64, 64)
    wpts = curve([(27, 31), (22.5, 22), (25, 11.5), (34.5, 7), (43, 11.5), (42, 20)], 16)
    worm.line(wpts, 6.6)
    wm = worm.arr(0.5)
    union = np.maximum(km, wm)
    _outline(cv, union, 1.5)
    red = c((176, 78, 60))
    cyl = 1.10 - 0.30 * np.abs((X - 29) / 22.0) ** 1.6  # round side shading, light from the left
    cv.paint(red[None, None, :] * cyl[..., None], km)
    band = (Y > 39.5 + 3.4 * (1 - ((X - 32) / 19.0) ** 2).clip(0, 1) * 1.0) & (Y < 48.5 + 3.4 * (1 - ((X - 32) / 19.0) ** 2).clip(0, 1))
    cv.paint(c((234, 222, 190))[None, None, :] * cyl[..., None], band.astype(np.float32) * km)
    # the open top: rim, then soil
    rim = cov(sd_ellipse(X, Y, 32, 30, 19, 7))
    cv.paint(c(INKBROWN), 0.9 * cov(sd_ellipse(X, Y, 32, 30, 19.9, 7.9)) * km)
    cv.paint(c((206, 198, 180)), rim)
    soil = cov(sd_ellipse(X, Y, 32, 30.4, 16.4, 5.2))
    cv.paint(c(INKBROWN), 0.8 * cov(sd_ellipse(X, Y, 32, 30.4, 17.2, 6.0)) * rim)
    cv.paint(c((78, 54, 38)), soil)
    # the worm comes out of the soil
    wvis = wm * np.maximum((Y < 30.5).astype(np.float32), 0)
    wvis = np.maximum(wvis, wm * soil)
    cv.paint(c(INKBROWN), 0.9 * np.clip((1.2 - outside_dist(wm)) * S + 0.5, 0, 1) * np.maximum(soil, (Y < 30.5)))
    pink = c((226, 142, 132))
    cv.paint(pink, wvis)
    seg = MaskDraw(64, 64)
    for i in range(6, len(wpts) - 6, 9):
        (x0, y0), (x1, y1) = wpts[i - 1], wpts[i + 1]
        nx, ny = -(y1 - y0), (x1 - x0)
        n = np.hypot(nx, ny) + 1e-6
        nx, ny = nx / n * 2.8, ny / n * 2.8
        seg.line([(wpts[i][0] - nx, wpts[i][1] - ny), (wpts[i][0] + nx, wpts[i][1] + ny)], 0.9)
    cv.paint(c((168, 88, 84)), 0.7 * seg.arr(0.15) * wvis)
    hl = MaskDraw(64, 64)
    hl.line(curve([(22.6, 19), (25.4, 12.6), (32, 8.6)], 10), 1.3)
    cv.light(0.45 * hl.arr(0.3) * wvis)
    return _finish_icon(cv, 251)


def sd_ellipse(X, Y, cx, cy, rx, ry):
    """Good enough near the edge for anti-aliasing: scaled circle distance."""
    k = np.hypot((X - cx) / rx, (Y - cy) / ry)
    return (k - 1) * min(rx, ry)


# ----------------------------------------------------------------------------- the spec (one source for the README)

# name, builder, slice (l, t, r, b) or None, tint, use
SPEC = [
    ("paper_card.png", paper_card, (24, 24, 232, 232), False,
     "Anything you read: the catch card plate, journal pages, goal list, toasts. Ink text. The paper edge sits 9 px in (top 7, bottom 12): the rest of the margin is the shadow."),
    ("canvas_panel.png", canvas_panel, (72, 72, 184, 184), False,
     "Shop and tackle box inner panels, list backgrounds. Ink text. Leather corners 56 px; hem 12 px."),
    ("leather_panel.png", leather_panel, (76, 76, 180, 180), False,
     "The shop and tackle box frame, HUD strap. Paper-colour text (236,226,200). Stitches turn each corner; the straight runs carry a creased line."),
    ("brass_button.png", lambda: brass_button(False), (16, 16, 112, 44), False,
     "Buttons, key caps, price tags. Ink text, centred on the face (the face is rows 3 to 53; the lip and shadow are below it)."),
    ("brass_button_pressed.png", lambda: brass_button(True), (16, 16, 112, 44), False,
     "The same button held down: swap the image and move the label down 4 px x SliceScale."),
    ("tackle_tab.png", tackle_tab, (36, 0, 100, 96), False,
     "The side buttons as tabs on the box edge (left side of the screen). Stretch sideways only: set SliceScale = height / 96. Ink text and icon from x = 22 x SliceScale."),
    ("fight_frame.png", fight_frame, (30, 26, 226, 36), False,
     "Wood and brass frame for the fight bar; works upright or lying down without rotating. The window is see-through: put it over the track. Rail 13 px; the window is x 16 to 240, y 15 to 46."),
    ("water_track.png", water_track, (10, 10, 246, 22), False,
     "The fight bar track, under the frame. Zone and marker go on top."),
    ("fish_marker.png", fish_marker, None, True,
     "The fight bar marker (head to the right; Rotation for upright bars). White with a darker rim of the same tint."),
    ("rarity_seal.png", rarity_seal, None, True,
     "The rarity stamp on the catch card and journal. Tint with the rarity colour; a few degrees of Rotation looks stamped."),
    ("rarity_ribbon.png", rarity_ribbon, (28, 0, 100, 32), True,
     "A ribbon in the rarity colour, the rarity name on it. Stretch sideways only: SliceScale = height / 32."),
    ("weight_tag.png", weight_tag, None, False,
     "The hanging weight tag on the catch card. Ink text inside x 21 to 75, y 56 to 116. The string runs off the top: hang it from the card's top edge."),
    ("icon_coin.png", icon_coin, None, False, "HUD coin, prices."),
    ("icon_creel.png", icon_creel, None, False, "HUD bag (the creel)."),
    ("icon_dial.png", icon_dial, None, False,
     "HUD time dial: day on top (noon is straight up), night below. The code turns a hand about the centre."),
    ("icon_dial_hand.png", icon_dial_hand, None, False,
     "The dial's hand, pointing up (noon). Same size and centre as the dial: lay it over and set Rotation."),
    ("icon_journal.png", icon_journal, None, False, "Journal tab."),
    ("icon_goals.png", icon_goals, None, False, "Goals tab."),
    ("icon_bait.png", icon_bait, None, False, "Bait tab."),
    ("ruler_strip.png", ruler_strip, None, True,
     "The ruled length line on the catch card. White: set ImageColor3 to ink (38,34,30). Tiles every 256 px (ScaleType Tile); long tick every 32 px, short every 8."),
    ("stitch_strip.png", stitch_strip, None, True,
     "Extra: a tiling stitch line (ScaleType Tile, TileSize 64 x 12) for a full stitched border where wanted. Tint with thread (230,214,172)."),
]


def lum(rgb):
    v = np.asarray(rgb, np.float64) / 255
    v = np.where(v <= 0.03928, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)
    return v @ np.array([0.2126, 0.7152, 0.0722])


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def worst_contrast(im, box, text):
    """Contrast of the text colour against the worst 2 percent of pixels in the text area."""
    a = np.asarray(im.convert("RGBA"), np.float64)[box[1]:box[3], box[0]:box[2], :3].reshape(-1, 3)
    ls = np.array([lum(p) for p in a])
    lt = lum(text)
    if lt > ls.mean():
        pick = np.percentile(ls, 98)
        return (lt + 0.05) / (pick + 0.05)
    pick = np.percentile(ls, 2)
    return (pick + 0.05) / (lt + 0.05)


TEXT_AREAS = [  # file, text box, text colour
    ("paper_card.png", (24, 24, 232, 232), INK),
    ("canvas_panel.png", (44, 44, 212, 212), INK),
    ("leather_panel.png", (28, 28, 228, 228), PAPER),
    ("brass_button.png", (14, 10, 114, 48), INK),
    ("brass_button_pressed.png", (14, 14, 114, 52), INK),
    ("tackle_tab.png", (22, 14, 114, 80), INK),
    ("weight_tag.png", (21, 56, 75, 116), INK),
]


def build_images():
    os.makedirs(OUT, exist_ok=True)
    ims = {}
    for name, fn, _slice, _tint, _use in SPEC:
        im = fn()
        im.save(os.path.join(OUT, name), optimize=True)
        ims[name] = im
        print(f"  {name:28s} {im.size[0]}x{im.size[1]}")
    return ims


def write_readme(ims):
    rows = []
    for name, _fn, sl, tint, use in SPEC:
        w, h = ims[name].size
        srect = f"{sl[0]}, {sl[1]}, {sl[2]}, {sl[3]}" if sl else "none"
        rows.append(f"| `{name}` | {w} x {h} | {srect} | {use} | {'yes' if tint else 'no'} |")
    crow = []
    for name, box, text in TEXT_AREAS:
        k = worst_contrast(ims[name], box, text)
        crow.append(f"| `{name}` | {text[0]},{text[1]},{text[2]} | {k:.1f} to 1 | {'pass' if k >= 4.5 else 'FAIL'} |")
    rrow = []
    for nm, col in RARITY:
        rrow.append(f"| {nm} | {col[0]},{col[1]},{col[2]} | {contrast(col, INK):.1f} to 1 | {contrast(col, PAPER):.1f} to 1 |")
    text = f"""# UI art: the field guide and the tackle box

Leg 3, N2. Drawn by `art/scripts/ui_art.py` (Pillow, numpy, scipy), 11/27/2026. Not yet uploaded or seen in Studio. Rebuild everything, this page included:

```powershell
cd "C:\\Users\\stewa\\Documents\\Claude\\Roblox"; python "C:\\Users\\stewa\\Documents\\Claude\\Roblox\\art\\scripts\\ui_art.py"
```

![Sheet](sheet.png)

Phone mockups at the real 667 x 375 size are in `preview/` (`mock_hud.png`, `mock_catch.png`, `mock_shop.png`). They are layouts to judge the art by, not the final UI.

## The images

SliceCenter is `Rect.new(left, top, right, bottom)` in image pixels. All PNGs have alpha, with the colour bled into the clear pixels so Roblox shows no dark fringe.

| File | Size | SliceCenter (left, top, right, bottom) | Use | Tint |
|---|---|---|---|---|
{chr(10).join(rows)}

## Notes for the UI code

- **SliceScale.** The panels are drawn chunky so they can be shown small. On a 667 x 375 phone the mockups use SliceScale 0.5 for the three panels (0.4 for small paper rows, 0.3 for the HUD strap) and about 0.7 for buttons and the fight frame.
- **Nothing repeats in a stretch zone.** Stitches and corner pieces sit in the corners; the stretched middles carry only flat texture and continuous lines. For stitches all the way round, tile `stitch_strip.png` along the edge.
- **Shadows are inside the images.** Panels, buttons, the tab and the tag carry their own soft shadow in the alpha, so no extra shadow frames are needed. Lay content out from the SliceCenter, not the image edge.
- **Tintable images are white.** Set `ImageColor3`. The ruler needs ink (38,34,30); left white it will not show on paper.
- **Colours used.** Paper 236,226,200. Ink 38,34,30. Brass 176,136,72. Canvas 188,170,126. Leather 120,78,48. Thread 230,214,172. Wood 122,92,62. Water 44,104,140. Manila (tab) 228,212,172.

## Contrast, measured

Text colour against the worst 2 percent of pixels where the text goes (the phone rule is 4.5 to 1).

| Surface | Text colour | Contrast | 4.5 to 1 |
|---|---|---|---|
{chr(10).join(crow)}

Rarity colours are unchanged. They were picked for dark panels, so on paper they are pale:

| Rarity | Colour | Ink text on the ribbon | Seal against paper |
|---|---|---|---|
{chr(10).join(rrow)}

So: the rarity name goes in ink on the ribbon (Epic is the weakest; keep that label bold and at least 19 px, or set it beside the ribbon in ink), and the seal is a mark of colour, not something to read. It never carries the only copy of the rarity.
"""
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as f:
        f.write(text)


# ----------------------------------------------------------------------------- sheet and phone mockups

def font(kind, size):
    names = {
        "serif": ["georgiab.ttf", "georgia.ttf"],
        "serif-r": ["georgia.ttf"],
        "sans": ["segoeui.ttf", "arial.ttf"],
        "sans-b": ["segoeuib.ttf", "arialbd.ttf"],
        "hand": ["segoepr.ttf", "segoesc.ttf", "georgiai.ttf"],
    }[kind]
    for n in names:
        p = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def nine(im, rc, tw, th, sc=1.0):
    """What Roblox does with ScaleType Slice."""
    l, t, r, b = rc
    W, H = im.size
    L, T, R, B = int(round(l * sc)), int(round(t * sc)), int(round((W - r) * sc)), int(round((H - b) * sc))
    xs, ys = [0, l, r, W], [0, t, b, H]
    xd, yd = [0, L, tw - R, tw], [0, T, th - B, th]
    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    for i in range(3):
        for j in range(3):
            sw, sh = xs[i + 1] - xs[i], ys[j + 1] - ys[j]
            dw, dh = xd[i + 1] - xd[i], yd[j + 1] - yd[j]
            if min(sw, sh, dw, dh) <= 0:
                continue
            piece = im.crop((xs[i], ys[j], xs[i + 1], ys[j + 1])).resize((dw, dh), Image.LANCZOS)
            out.paste(piece, (xd[i], yd[j]))
    return out


def tint(im, col):
    a = np.asarray(im, np.float32).copy()
    a[..., :3] *= np.array(col, np.float32)[None, None, :] / 255
    return Image.fromarray((a + 0.5).astype(np.uint8), "RGBA")


def scaled(im, w, h=None):
    h = h or int(round(im.size[1] * w / im.size[0]))
    return im.resize((int(w), int(h)), Image.LANCZOS)


def put(base, im, x, y, rot=0.0):
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    base.alpha_composite(im, (int(round(x)), int(round(y))))


def text(base, xy, s, f, fill, anchor="la", shadow=None):
    d = ImageDraw.Draw(base)
    if shadow:
        d.text((xy[0] + 1, xy[1] + 1), s, font=f, fill=shadow, anchor=anchor)
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def backdrop(w=667, h=375):
    """A stand-in for the game: dusk sky, far treeline, teal water. Only there to judge the art against."""
    ys = np.linspace(0, 1, h)[:, None]
    sky = np.array([150, 176, 190]) * (1 - ys / 0.45).clip(0, 1) + np.array([226, 200, 160]) * (ys / 0.45).clip(0, 1)
    water = np.array([34, 82, 78]) * (1 - (ys - 0.45) / 0.55).clip(0, 1) + np.array([20, 50, 52]) * ((ys - 0.45) / 0.55).clip(0, 1)
    img = np.where(ys < 0.45, sky, water)
    img = np.repeat(img[:, None, :], w, axis=1).reshape(h, w, 3).astype(np.float32)
    r = np.random.default_rng(5)
    hill = ndi.gaussian_filter1d(r.random(w + 40), 9)[:w]
    hill = (hill - hill.min()) / (hill.max() - hill.min())
    for x in range(w):
        top = int(h * (0.36 - 0.08 * hill[x]))
        img[top:int(h * 0.46), x] = np.array([52, 78, 62]) * (0.9 + 0.15 * hill[x])
    img += r.normal(0, 2.0, img.shape)
    # the dock in the foreground
    img[int(h * 0.80):, int(w * 0.30):int(w * 0.72)] = np.array([122, 104, 86]) * (0.92 + 0.08 * r.random((h - int(h * 0.80), int(w * 0.72) - int(w * 0.30), 1)))
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def mock_hud(ims):
    b = backdrop()
    ink, paper = INK, PAPER
    # top strap: coin and number, dial, creel and count
    put(b, nine(ims["leather_panel.png"], (76, 76, 180, 180), 300, 50, 0.30), 183, 2)
    put(b, scaled(ims["icon_coin.png"], 32), 200, 10)
    text(b, (238, 26), "1,240", font("serif", 19), paper, "lm")
    put(b, scaled(ims["icon_creel.png"], 34), 398, 8)
    text(b, (436, 26), "7 / 20", font("sans-b", 16), paper, "lm")
    put(b, scaled(ims["icon_dial.png"], 52), 307, 2)
    put(b, scaled(ims["icon_dial_hand.png"], 52), 307, 2, rot=-52)
    put(b, nine(ims["paper_card.png"], (24, 24, 232, 232), 104, 34, 0.32), 281, 52)
    text(b, (333, 67), "Dusk, clear", font("sans-b", 14), ink, "mm")
    # tabs on the box edge
    for i, (ic, lab) in enumerate((("icon_bait.png", "Worms"), ("icon_journal.png", "Journal"), ("icon_goals.png", "Goals"))):
        y = 112 + i * 52
        put(b, nine(ims["tackle_tab.png"], (36, 0, 100, 96), 138, 52, 52 / 96), 0, y)
        put(b, scaled(ims["icon_bait.png" if i == 0 else ic], 34), 16, y + 8)
        text(b, (56, y + 25), lab, font("sans-b", 16), ink, "lm")
    # fight bar, upright
    fx, fy, tw, th = 548, 96, 44, 190
    put(b, nine(ims["water_track.png"], (10, 10, 246, 22), tw, th, 0.6), fx, fy)
    zone = Image.new("RGBA", (tw - 4, 52), (95, 200, 110, 120))
    put(b, zone, fx + 2, fy + 78)
    put(b, tint(scaled(ims["fish_marker.png"], 50), (255, 170, 80)), fx - 3, fy + 88)
    put(b, nine(ims["fight_frame.png"], (30, 26, 226, 36), tw + 22, th + 22, 0.72), fx - 11, fy - 11)
    text(b, (fx + 22, fy + th + 26), "Hold to reel", font("sans-b", 14), paper, "mm", shadow=(0, 0, 0))
    # buttons
    put(b, nine(ims["brass_button.png"], (16, 16, 112, 44), 132, 50, 0.72), 222, 312)
    text(b, (288, 333), "Cast", font("serif", 18), ink, "mm")
    put(b, nine(ims["brass_button_pressed.png"], (16, 16, 112, 44), 132, 50, 0.72), 366, 312)
    text(b, (432, 336), "Cast", font("serif", 18), ink, "mm")
    return b


def mock_catch(ims):
    b = backdrop()
    ink = INK
    x0, y0, w, h = 246, 74, 380, 232
    put(b, nine(ims["paper_card.png"], (24, 24, 232, 232), w, h, 0.5), x0, y0)
    text(b, (x0 + 26, y0 + 22), "Bluegill", font("serif", 24), ink)
    text(b, (x0 + 27, y0 + 52), "Home lake, by the reeds", font("sans", 14), (86, 78, 68))
    # the fish plate: a stand-in for the turning model
    cvf = Cv(190, 96)
    m, eye, er = fish_mask(190, 96, 95, 46, 168, fin=0.25)
    cvf.paint(c((92, 112, 96)), m)
    cvf.paint(c(INKBROWN), 0.9 * np.clip((1.2 - outside_dist(m)) * S + 0.5, 0, 1) * (1 - m))
    cvf.paint(c(INK), cov(sd_circle(cvf.X, cvf.Y, eye[0], eye[1], er)))
    put(b, cvf.image(), x0 + 24, y0 + 72)
    rl = tint(ims["ruler_strip.png"], ink).crop((0, 0, 170, 32))
    put(b, scaled(rl, 170 * 0.72, 32 * 0.72), x0 + 36, y0 + 168)
    text(b, (x0 + 36, y0 + 194), "0", font("sans", 14), ink, "ma")
    text(b, (x0 + 36 + 122, y0 + 194), "18 cm", font("sans-b", 14), ink, "ma")
    text(b, (x0 + 222, y0 + 98), "A good one", font("hand", 14), (70, 62, 54))
    text(b, (x0 + 222, y0 + 118), "for the pan.", font("hand", 14), (70, 62, 54))
    # the tag hangs from the top edge, the seal is stamped lower right
    put(b, scaled(ims["weight_tag.png"], 72), x0 + w - 104, y0 - 16, rot=-4)
    text(b, (x0 + w - 66, y0 + 44), "0.4", font("serif", 20), ink, "mm")
    text(b, (x0 + w - 66, y0 + 63), "kg", font("sans-b", 14), ink, "mm")
    col = dict(RARITY)["Uncommon"]
    put(b, tint(scaled(ims["rarity_seal.png"], 62), col), x0 + w - 100, y0 + h - 96, rot=-12)
    put(b, tint(nine(ims["rarity_ribbon.png"], (28, 0, 100, 32), 132, 26, 26 / 32), col), x0 + 140, y0 + 20)
    text(b, (x0 + 206, y0 + 31), "Uncommon", font("sans-b", 14), ink, "mm")
    put(b, nine(ims["brass_button.png"], (16, 16, 112, 44), 110, 46, 0.66), 70, 256)
    text(b, (125, 276), "Keep", font("serif", 17), ink, "mm")
    return b


def mock_shop(ims):
    b = backdrop()
    ink, paper = INK, PAPER
    x0, y0, w, h = 86, 28, 520, 326
    put(b, nine(ims["leather_panel.png"], (76, 76, 180, 180), w, h, 0.5), x0, y0)
    text(b, (x0 + w // 2, y0 + 32), "Bait Shack", font("serif", 22), paper, "mm")
    put(b, scaled(ims["icon_coin.png"], 26), x0 + w - 118, y0 + 19)
    text(b, (x0 + w - 88, y0 + 32), "1,240", font("sans-b", 16), paper, "lm")
    cx, cy, cw, ch = x0 + 22, y0 + 54, w - 44, h - 78
    put(b, nine(ims["canvas_panel.png"], (72, 72, 184, 184), cw, ch, 0.5), cx, cy)
    items = (("icon_bait.png", "Worms", "A tin of ten. Most fish like them.", "25"),
             ("icon_creel.png", "Bigger creel", "Room for ten more fish.", "400"),
             ("icon_journal.png", "Reed notes", "A page on where the perch hide.", "120"))
    for i, (ic, nm, desc, price) in enumerate(items):
        ry = cy + 22 + i * 70
        put(b, nine(ims["paper_card.png"], (24, 24, 232, 232), cw - 76, 68, 0.4), cx + 38, ry)
        put(b, scaled(ims[ic], 40), cx + 52, ry + 12)
        text(b, (cx + 102, ry + 22), nm, font("serif", 17), ink, "lm")
        text(b, (cx + 102, ry + 43), desc, font("sans", 14), (70, 62, 54), "lm")
        put(b, nine(ims["brass_button_pressed.png" if i == 1 else "brass_button.png"], (16, 16, 112, 44), 96, 46, 0.66), cx + cw - 150, ry + 10)
        put(b, scaled(ims["icon_coin.png"], 20), cx + cw - 136, ry + 20 + (3 if i == 1 else 0))
        text(b, (cx + cw - 92, ry + 30 + (3 if i == 1 else 0)), price, font("sans-b", 16), ink, "mm")
    return b


def build_sheet(ims):
    os.makedirs(PREVIEW, exist_ok=True)
    mocks = {"mock_hud.png": mock_hud(ims), "mock_catch.png": mock_catch(ims), "mock_shop.png": mock_shop(ims)}
    for n, m in mocks.items():
        m.convert("RGB").save(os.path.join(PREVIEW, n))
    W, H = 2060, 1580
    sh = Image.new("RGBA", (W, H), (58, 64, 66, 255))
    lab = font("sans", 13)
    head = font("sans-b", 17)
    text(sh, (20, 12), "UI art: the field guide and the tackle box  (leg 3, N2)   every image at 1 to 1, then stretched, then on a 667 x 375 phone", head, (236, 226, 200))

    def cell(name, x, y, bg=None):
        im = ims[name]
        if bg:
            sh.paste(Image.new("RGBA", (im.size[0] + 12, im.size[1] + 12), bg + (255,)), (x - 6, y - 6))
        put(sh, im, x, y)
        text(sh, (x, y + im.size[1] + 8), f"{name[:-4]}  {im.size[0]}x{im.size[1]}", lab, (214, 208, 190))

    # row 1: panels
    cell("paper_card.png", 20, 50)
    cell("canvas_panel.png", 296, 50)
    cell("leather_panel.png", 572, 50)
    cell("brass_button.png", 848, 50)
    cell("brass_button_pressed.png", 848, 144)
    cell("tackle_tab.png", 1000, 50)
    cell("weight_tag.png", 1016, 176)
    cell("fight_frame.png", 1140, 50)
    cell("water_track.png", 1140, 150)
    put(sh, ims["water_track.png"], 1155, 245)
    put(sh, ims["fight_frame.png"], 1140, 229)
    text(sh, (1140, 301), "frame over track", lab, (214, 208, 190))
    # tintables on paper
    px, py = 1410, 44
    sh.paste(Image.new("RGBA", (630, 300), PAPER + (255,)), (px, py))
    for i, (nm, col) in enumerate(RARITY):
        put(sh, tint(scaled(ims["rarity_seal.png"], 88), col), px + 10 + i * 102, py + 8, rot=(-10 + 4 * i))
        put(sh, tint(scaled(ims["rarity_ribbon.png"], 100), col), px + 6 + i * 102, py + 112)
        text(sh, (px + 56 + i * 102, py + 124), nm, font("sans-b", 13), INK, "mm")
    put(sh, tint(ims["ruler_strip.png"], INK), px + 10, py + 152)
    put(sh, tint(ims["ruler_strip.png"], INK), px + 266, py + 152)
    put(sh, tint(ims["fish_marker.png"], (255, 170, 80)), px + 540, py + 150)
    put(sh, tint(ims["stitch_strip.png"], (120, 78, 48)), px + 10, py + 196)
    put(sh, tint(ims["stitch_strip.png"], (120, 78, 48)), px + 74, py + 196)
    put(sh, ims["rarity_seal.png"].resize((128, 128)), px + 10, py + 300 + 14)
    text(sh, (px + 10, py + 230), "seal, ribbon, ruler (tiled twice), fish marker and stitch strip, tinted. Below: as drawn (white)", lab, INK)
    put(sh, ims["rarity_ribbon.png"], px + 150, py + 330)
    put(sh, ims["fish_marker.png"], px + 300, py + 330)
    put(sh, ims["ruler_strip.png"], px + 150, py + 380)
    put(sh, ims["stitch_strip.png"], px + 380, py + 340)
    # row 2: icons at 64 and at phone size, on dark, paper and leather
    iy = 340
    icons = ["icon_coin.png", "icon_creel.png", "icon_dial.png", "icon_dial_hand.png", "icon_journal.png", "icon_goals.png", "icon_bait.png"]
    for k, bgc in enumerate(((58, 64, 66), PAPER, LEATHER)):
        sh.paste(Image.new("RGBA", (7 * 84 + 10, 78), bgc + (255,)), (20, iy + k * 84))
        for i, n in enumerate(icons):
            put(sh, ims[n], 30 + i * 84, iy + 7 + k * 84)
    for i, n in enumerate(icons):
        text(sh, (30 + i * 84, iy + 256), n[5:-4], lab, (214, 208, 190))
    sh.paste(Image.new("RGBA", (360, 50), PAPER + (255,)), (640, iy))
    sh.paste(Image.new("RGBA", (360, 50), (58, 64, 66, 255)), (640, iy + 56))
    for i, n in enumerate(icons):
        put(sh, scaled(ims[n], 32), 652 + i * 48, iy + 9)
        put(sh, scaled(ims[n], 32), 652 + i * 48, iy + 65)
    text(sh, (640, iy + 112), "icons at 32 px (phone size)", lab, (214, 208, 190))
    dial = ims["icon_dial.png"].copy()
    put(dial, ims["icon_dial_hand.png"], 0, 0, rot=0)
    for i, ang in enumerate((0, -70, -150, -230)):
        d2 = ims["icon_dial.png"].copy()
        hand = ims["icon_dial_hand.png"].rotate(ang, resample=Image.BICUBIC)
        d2.alpha_composite(hand)
        put(sh, d2, 640 + i * 76, iy + 140)
    text(sh, (640, iy + 210), "dial with the hand turned by the code", lab, (214, 208, 190))
    # row 3: stretch tests (true nine-slice)
    sy = 640
    text(sh, (20, sy - 26), "Stretch tests (what ScaleType Slice does), SliceScale 0.5", head, (236, 226, 200))
    put(sh, nine(ims["paper_card.png"], (24, 24, 232, 232), 420, 200, 0.5), 20, sy)
    put(sh, nine(ims["canvas_panel.png"], (72, 72, 184, 184), 420, 200, 0.5), 460, sy)
    put(sh, nine(ims["leather_panel.png"], (76, 76, 180, 180), 420, 200, 0.5), 900, sy)
    put(sh, nine(ims["leather_panel.png"], (76, 76, 180, 180), 640, 110, 0.5), 1340, sy)
    put(sh, nine(ims["canvas_panel.png"], (72, 72, 184, 184), 640, 80, 0.5), 1340, sy + 118)
    yy = sy + 214
    put(sh, nine(ims["brass_button.png"], (16, 16, 112, 44), 220, 48, 0.7), 20, yy)
    put(sh, nine(ims["brass_button_pressed.png"], (16, 16, 112, 44), 220, 48, 0.7), 250, yy)
    put(sh, nine(ims["brass_button.png"], (16, 16, 112, 44), 64, 44, 0.6), 480, yy)
    put(sh, nine(ims["tackle_tab.png"], (36, 0, 100, 96), 190, 50, 50 / 96), 560, yy)
    put(sh, nine(ims["tackle_tab.png"], (36, 0, 100, 96), 110, 50, 50 / 96), 760, yy)
    put(sh, nine(ims["water_track.png"], (10, 10, 246, 22), 400, 26, 0.6), 895, yy + 12)
    put(sh, nine(ims["fight_frame.png"], (30, 26, 226, 36), 420, 46, 0.72), 885, yy + 2)
    put(sh, nine(ims["water_track.png"], (10, 10, 246, 22), 44, 190, 0.6), 1351, yy + 11 - 20)
    put(sh, nine(ims["fight_frame.png"], (30, 26, 226, 36), 66, 212, 0.72), 1340, yy - 20)
    put(sh, tint(nine(ims["rarity_ribbon.png"], (28, 0, 100, 32), 220, 28, 28 / 32), dict(RARITY)["Legendary"]), 1440, yy + 10)
    text(sh, (1550, yy + 22), "Legendary", font("sans-b", 14), INK, "mm")
    # row 4: phone mockups, actual size, then 2x
    my = 1090
    text(sh, (20, my - 28), "Phone mockups, 667 x 375, actual size (layouts are stand-ins; the UI code decides)", head, (236, 226, 200))
    for i, n in enumerate(("mock_hud.png", "mock_catch.png", "mock_shop.png")):
        sh.alpha_composite(mocks[n], (20 + i * 680, my))
        text(sh, (20 + i * 680, my + 381), n, lab, (214, 208, 190))
    text(sh, (20, my + 410), "Contrast (text colour against the worst 2 percent of the text area)", head, (236, 226, 200))
    for i, (name, box, tx) in enumerate(TEXT_AREAS):
        k = worst_contrast(ims[name], box, tx)
        text(sh, (20 + (i % 4) * 500, my + 440 + (i // 4) * 22), f"{name[:-4]}: {k:.1f} to 1  {'pass' if k >= 4.5 else 'FAIL'}", lab, (214, 208, 190))
    sh.convert("RGB").save(os.path.join(OUT, "sheet.png"), optimize=True)
    print("  sheet.png, preview/mock_*.png")


def firefly_dot():
    """The fireflies' particle (N1 review 1): a 64 x 64 soft white dot, alpha falling off like a
    glow (a hot core, a gaussian halo to the edge), white so the emitter's Color tints it."""
    n = 64
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    r = np.hypot(x - (n - 1) / 2, y - (n - 1) / 2) / (n / 2)  # 0 centre, 1 edge
    a = 0.65 * np.exp(-(r / 0.42) ** 2) + 0.35 * np.exp(-(r / 0.16) ** 2)
    a = np.clip(a * np.clip((1 - r) / 0.12, 0, 1), 0, 1)  # exactly clear at the rim
    rgba = np.zeros((n, n, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = np.round(a * 255).astype(np.uint8)
    path = os.path.join(OUT, "firefly_dot.png")
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)
    print("  firefly_dot.png")


def main():
    if "--firefly-dot" in sys.argv:  # python art/scripts/ui_art.py --firefly-dot (this one image only)
        firefly_dot()
        return
    print("UI art ->", OUT)
    ims = build_images()
    write_readme(ims)
    if "--no-sheet" not in sys.argv:
        build_sheet(ims)
    for name, box, tx in TEXT_AREAS:
        k = worst_contrast(ims[name], box, tx)
        print(f"  contrast {name:28s} {k:4.1f} to 1  {'pass' if k >= 4.5 else 'FAIL'}")


if __name__ == "__main__":
    main()
