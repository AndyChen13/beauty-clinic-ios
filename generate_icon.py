#!/usr/bin/env python3
from PIL import Image, ImageDraw

size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background circle
draw.ellipse([0, 0, size, size], fill=(41, 98, 180, 255))

center = size // 2

# Main diamond sparkle
diamond_size = 180
points = [
    (center, center - diamond_size),
    (center + int(diamond_size * 0.6), center),
    (center, center + diamond_size),
    (center - int(diamond_size * 0.6), center)
]
draw.polygon(points, fill=(255, 255, 255, 230))

# Small sparkles
sparkle_size = 60
for dx, dy in [(-200, -150), (200, -100), (-150, 180), (180, 150)]:
    sx, sy = center + dx, center + dy
    s = sparkle_size
    draw.polygon([
        (sx, sy - s), (sx + int(s*0.4), sy), (sx, sy + s), (sx - int(s*0.4), sy)
    ], fill=(255, 255, 255, 180))

# Save
output_path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
img.save(output_path)
print(f'App icon saved to {output_path}')
