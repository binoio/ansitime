#!/usr/bin/env python3
import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def generate_icon_image(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    margin = int(size * 0.05)
    squircle_w = size - 2 * margin
    radius = int(squircle_w * 0.224)

    # 1. Bezel Gradient
    bezel = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bezel)
    for y in range(margin, size - margin):
        ratio = (y - margin) / squircle_w
        r = int(32 * (1.0 - ratio * 0.75))
        g = int(28 * (1.0 - ratio * 0.75))
        b = int(24 * (1.0 - ratio * 0.75))
        b_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([margin, margin, size - margin, size - margin], radius=radius, fill=255)
    bezel.putalpha(mask)
    img.alpha_composite(bezel)

    ImageDraw.Draw(img).rounded_rectangle([margin, margin, size - margin, size - margin], radius=radius, outline=(70, 60, 50, 200), width=max(1, int(size * 0.008)))

    # 2. Inner CRT Monitor Screen
    s_inset = int(squircle_w * 0.075)
    screen_rect = [margin + s_inset, margin + s_inset, size - margin - s_inset, size - margin - s_inset]
    screen_w = screen_rect[2] - screen_rect[0]
    screen_radius = int(radius * 0.65)

    screen_mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle(screen_rect, radius=screen_radius, fill=255)

    screen_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cx = size / 2.0
    cy = size / 2.0
    max_dist = screen_w * 0.65

    for y in range(screen_rect[1], screen_rect[3]):
        for x in range(screen_rect[0], screen_rect[2]):
            dist = math.hypot(x - cx, y - cy)
            glow = max(0.0, 1.0 - dist / max_dist)
            r = int(4 + 10 * glow)
            g = int(10 + 32 * glow)
            b = int(5 + 12 * glow)
            screen_layer.putpixel((x, y), (r, g, b, 255))

    sl_draw = ImageDraw.Draw(screen_layer)
    scanline_gap = max(3, int(size * 0.012))
    for y in range(screen_rect[1], screen_rect[3], scanline_gap):
        sl_draw.line([(screen_rect[0], y), (screen_rect[2], y)], fill=(0, 0, 0, 70), width=max(1, int(size * 0.004)))

    # 3. The 3 Gradient Blocks: ░ (176), ▒ (177), ▓ (178)
    p176 = [
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
        [0,0,1,0,0,0,1,0],
        [1,0,0,0,1,0,0,0],
    ]
    p177 = [
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1],
    ]
    p178 = [
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
        [1,0,1,1,1,0,1,1],
        [1,1,1,0,1,1,1,0],
    ]

    pixel_scale = max(1, int(size * 0.024))
    gap = 2 * pixel_scale
    cols_per_block = 8
    rows_per_block = 16

    block_w = cols_per_block * pixel_scale
    block_h = rows_per_block * pixel_scale
    total_w = 3 * block_w + 2 * gap
    total_h = block_h

    start_x = int(cx - total_w / 2.0)
    start_y = int(cy - total_h / 2.0)

    bloom_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bloom_draw = ImageDraw.Draw(bloom_layer)
    core_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    core_draw = ImageDraw.Draw(core_layer)

    patterns = [p176, p177, p178]
    phosphor_color = (80, 245, 95, 255)
    bloom_color = (40, 180, 60, 150)

    for b_idx, pat in enumerate(patterns):
        bx = start_x + b_idx * (block_w + gap)
        for r_idx in range(rows_per_block):
            row = pat[r_idx]
            py = start_y + r_idx * pixel_scale
            for c_idx, val in enumerate(row):
                if val == 1:
                    px = bx + c_idx * pixel_scale
                    inset = max(1, int(pixel_scale * 0.08)) if pixel_scale > 2 else 0
                    bloom_draw.rectangle([px - inset, py - inset, px + pixel_scale + inset, py + pixel_scale + inset], fill=bloom_color)
                    core_draw.rectangle([px + inset, py + inset, px + pixel_scale - inset, py + pixel_scale - inset], fill=phosphor_color)

    if pixel_scale > 2:
        bloom_blurred = bloom_layer.filter(ImageFilter.GaussianBlur(radius=pixel_scale * 0.5))
        screen_layer.alpha_composite(bloom_blurred)
    screen_layer.alpha_composite(core_layer)
    screen_layer.putalpha(screen_mask)
    img.alpha_composite(screen_layer)

    ImageDraw.Draw(img).rounded_rectangle(screen_rect, radius=screen_radius, outline=(15, 35, 18, 220), width=max(1, int(size * 0.006)))
    return img

def main():
    print("Generating master 1024x1024 icon...")
    master = generate_icon_image(1024)

    # Save to xcassets
    xcassets_icon = "Sources/ANSITime/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
    master.save(xcassets_icon, "PNG")
    print(f"Saved {xcassets_icon}")

    # Save to docs/icon.png
    docs_icon = "docs/icon.png"
    master.save(docs_icon, "PNG")
    print(f"Saved {docs_icon}")

    # Generate iconset
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for fname, sz in sizes:
        resized = master.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, fname), "PNG")

    print("Building AppIcon.icns via iconutil...")
    icns_path = "Sources/ANSITime/AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"Generated {icns_path}")

    # Clean up
    import shutil
    shutil.rmtree(iconset_dir)
    print("Done!")

if __name__ == "__main__":
    main()
