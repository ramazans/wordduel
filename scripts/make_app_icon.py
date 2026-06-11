#!/usr/bin/env python3
"""WordDuel app ikonu üretici.

Konsept: kelime düellosu = nokta-simetrik, kuyrukları birbirine bakan iki
konuşma balonu. Açık varyant mercan marka gradient'i üzerinde beyaz balonlar;
koyu varyantta zemin koyulaşır, balonlar mercana döner; tinted varyant
Apple'ın istediği gibi gri tonlamalı (siyah zemin, beyaz figür).
"""
from PIL import Image, ImageDraw

S = 1024
OUT = "wordduel/Assets.xcassets/AppIcon.appiconset"

CORAL_TOP = (255, 56, 92)      # FF385C
CORAL_BOTTOM = (215, 4, 102)   # D70466
CORAL_LINE = (230, 30, 77)     # E61E4D
DARK_BG_TOP = (38, 38, 42)
DARK_BG_BOTTOM = (17, 17, 20)
DARK_BUBBLE = (255, 90, 117)   # FF5A75
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            # Çapraz (sol üst → sağ alt) interpolasyon
            t = (x + y) / (2 * (S - 1))
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
    return img


def point_mirror(points):
    return [(S - x, S - y) for (x, y) in points]


def draw_bubbles(img, bubble_fill, line_fill):
    """Süperörnekleme ile pürüzsüz kenarlı balonlar çizer."""
    scale = 4
    layer = Image.new("RGBA", (S * scale, S * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def rr(box, radius, fill):
        d.rounded_rectangle([c * scale for c in box], radius=radius * scale, fill=fill)

    def poly(points, fill):
        d.polygon([(x * scale, y * scale) for (x, y) in points], fill=fill)

    # Balon 1 (sol üst) — kuyruk sol-alttaki konuşmacıya iner
    rr((170, 200, 590, 470), 90, bubble_fill)
    poly([(250, 455), (360, 455), (235, 575)], bubble_fill)
    # Kelime çizgileri
    rr((250, 272, 510, 312), 20, line_fill)
    rr((250, 352, 420, 392), 20, line_fill)

    # Balon 2 (sağ alt) — nokta simetrik, kuyruk sağ-üstteki konuşmacıya çıkar
    rr((434, 554, 854, 824), 90, bubble_fill)
    poly(point_mirror([(250, 455), (360, 455), (235, 575)]), bubble_fill)
    rr((514, 712, 774, 752), 20, line_fill)
    rr((604, 632, 774, 672), 20, line_fill)

    layer = layer.resize((S, S), Image.LANCZOS)
    img.paste(layer, (0, 0), layer)
    return img


def make(name, bg_top, bg_bottom, bubble, line):
    img = gradient(bg_top, bg_bottom).convert("RGBA")
    img = draw_bubbles(img, bubble + (255,), line + (255,))
    img.convert("RGB").save(f"{OUT}/{name}", "PNG")
    print(f"yazıldı: {name}")
    return img


light = make("AppIcon.png", CORAL_TOP, CORAL_BOTTOM, WHITE, CORAL_LINE)
make("AppIcon-Dark.png", DARK_BG_TOP, DARK_BG_BOTTOM, DARK_BUBBLE, DARK_BG_BOTTOM)
make("AppIcon-Tinted.png", BLACK, BLACK, WHITE, BLACK)

# Mac boyutları (açık varyanttan küçültme)
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        px = size * scale
        suffix = "@2x" if scale == 2 else ""
        fname = f"AppIcon-mac-{size}{suffix}.png"
        light.convert("RGB").resize((px, px), Image.LANCZOS).save(f"{OUT}/{fname}", "PNG")
        print(f"yazıldı: {fname}")
