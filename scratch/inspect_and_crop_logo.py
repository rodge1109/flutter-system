from PIL import Image

img = Image.open('assets/logo.png').convert('RGBA')
w, h = img.size
print(f"Original Logo Dimensions: {w}x{h}")

# Find column where the icon symbol ends and text begins
# We scan columns x from 0 to w to find empty/transparent space after the icon symbol
icon_max_x = 0
for x in range(w):
    has_pixel = False
    for y in range(h):
        r, g, b, a = img.getpixel((x, y))
        if a > 20:
            has_pixel = True
            break
    if has_pixel and x < 65: # The icon symbol is within the first ~60px
        icon_max_x = max(icon_max_x, x)

print(f"Icon symbol width bounds: 0 to {icon_max_x}")

# Crop the heart-paddle icon symbol (with a 2px padding on right)
icon_crop = img.crop((0, 0, min(icon_max_x + 3, w), h))

# Bounding box of actual non-transparent pixels in icon_crop
bbox = icon_crop.getbbox()
print(f"Icon Bounding Box: {bbox}")
if bbox:
    icon_cropped = icon_crop.crop(bbox)
else:
    icon_cropped = icon_crop

# Create 512x512 high resolution square canvas for app launcher icon
icon_512 = Image.new('RGBA', (512, 512), (0, 0, 0, 0))

# Resize icon symbol to fit within 400x400 (leaving clean ~56px margins around icon)
target_dim = 400
crop_w, crop_h = icon_cropped.size
scale = target_dim / max(crop_w, crop_h)
new_w = int(crop_w * scale)
new_h = int(crop_h * scale)

resized = icon_cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

paste_x = (512 - new_w) // 2
paste_y = (512 - new_h) // 2

icon_512.paste(resized, (paste_x, paste_y), resized)
icon_512.save('assets/app_icon.png')
print("Successfully generated assets/app_icon.png (512x512 icon-only)!")
