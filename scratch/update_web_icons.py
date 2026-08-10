import os
from PIL import Image

src_path = r"c:\agent_app\assets\logos\agent_logo.png"
if not os.path.exists(src_path):
    print("Logo not found at", src_path)
    exit(1)

img = Image.open(src_path).convert("RGBA")

# Destinations
targets = [
    (r"c:\agent_app\web\favicon.png", (64, 64)),
    (r"c:\agent_app\web\agent_logo.png", (256, 256)),
    (r"c:\agent_app\web\icons\Icon-192.png", (192, 192)),
    (r"c:\agent_app\web\icons\Icon-512.png", (512, 512)),
    (r"c:\agent_app\web\icons\Icon-maskable-192.png", (192, 192)),
    (r"c:\agent_app\web\icons\Icon-maskable-512.png", (512, 512)),
]

for out_path, size in targets:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(out_path, "PNG")
    print(f"Generated {out_path} ({size[0]}x{size[1]})")

print("All web icons generated successfully!")
