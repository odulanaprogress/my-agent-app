import os
from PIL import Image

src_path = r"c:\agent_app\assets\logos\agent_logo.png"
if not os.path.exists(src_path):
    print("Logo not found")
    exit(1)

img = Image.open(src_path).convert("RGBA")

# Threshold: If it has a solid background, this might just make a white square.
# Hopefully it's a transparent PNG.
r, g, b, a = img.split()
white = Image.new('L', img.size, 255)
mono_img = Image.merge('RGBA', (white, white, white, a))

sizes = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96
}

base_out = r"c:\agent_app\android\app\src\main\res"
for density, size in sizes.items():
    out_dir = os.path.join(base_out, f"drawable-{density}")
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, "ic_stat_onesignal_default.png")
    
    resized = mono_img.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(out_file)
    print(f"Saved {out_file}")
