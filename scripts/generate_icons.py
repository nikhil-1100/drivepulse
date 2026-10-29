"""Generate DrivePulse app icons from a single vector-ish master drawing.

Run from the project root:

    python scripts/generate_icons.py

The mark: a crimson squircle with a white drive and a telemetry pulse line.
No external assets are required, which keeps the repo reproducible.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
SCALE = 4


def draw_master() -> Image.Image:
    size = SIZE * SCALE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Vertical crimson gradient background.
    gradient = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(gradient)
    top = (240, 58, 58)
    bottom = (138, 0, 16)
    for y in range(size):
        t = y / (size - 1)
        colour = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=colour + (255,))

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * 0.225), fill=255
    )
    image.paste(gradient, (0, 0), mask)

    draw = ImageDraw.Draw(image)
    white = (255, 255, 255, 255)
    crimson = (240, 58, 58, 255)

    # Drive body.
    body = [int(size * 0.205), int(size * 0.325), int(size * 0.795), int(size * 0.675)]
    draw.rounded_rectangle(body, radius=int(size * 0.068), fill=white)
    draw.rounded_rectangle(
        [int(size * 0.263), int(size * 0.388), int(size * 0.607), int(size * 0.435)],
        radius=int(size * 0.024),
        fill=(255, 226, 226, 255),
    )
    draw.ellipse(
        [
            int(size * 0.686),
            int(size * 0.392),
            int(size * 0.740),
            int(size * 0.446),
        ],
        fill=crimson,
    )

    # Telemetry pulse.
    points = [
        (int(size * 0.165), int(size * 0.790)),
        (int(size * 0.295), int(size * 0.790)),
        (int(size * 0.352), int(size * 0.715)),
        (int(size * 0.414), int(size * 0.840)),
        (int(size * 0.470), int(size * 0.790)),
        (int(size * 0.835), int(size * 0.790)),
    ]
    draw.line(points, fill=white, width=int(size * 0.042), joint="curve")
    for x, y in (points[0], points[-1]):
        r = int(size * 0.021)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=white)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def write(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path)
    print(f"{path.relative_to(ROOT)}  {size}x{size}")


def main() -> None:
    master = draw_master()
    icon_dir = ROOT / "assets" / "icon"
    icon_dir.mkdir(parents=True, exist_ok=True)
    master.save(icon_dir / "drivepulse_icon.png")

    densities = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in densities.items():
        write(
            master,
            ROOT / "android/app/src/main/res" / f"mipmap-{density}" / "ic_launcher.png",
            size,
        )

    write(master, ROOT / "web/favicon.png", 32)
    write(master, ROOT / "web/icons/Icon-192.png", 192)
    write(master, ROOT / "web/icons/Icon-512.png", 512)
    write(master, ROOT / "web/icons/Icon-maskable-192.png", 192)
    write(master, ROOT / "web/icons/Icon-maskable-512.png", 512)

    app_icon_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for existing in app_icon_dir.glob("Icon-App-*.png"):
        with Image.open(existing) as handle:
            width = handle.width
        write(master, existing, width)


if __name__ == "__main__":
    main()
