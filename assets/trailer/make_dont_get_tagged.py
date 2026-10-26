"""Render matching trailer titles with Can Clash's in-game Titan One font.

Usage: python make_dont_get_tagged.py "TAG THEM BACK" tag_them_back_green.png green
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont


HERE = Path(__file__).resolve().parent
FONT = HERE.parent / "fonts" / "TitanOne-Regular.ttf"
OUTPUT = HERE / (sys.argv[2] if len(sys.argv) > 2 else "dont_get_tagged_red.png")
SIZE = (3840, 800)
TEXT = sys.argv[1] if len(sys.argv) > 1 else "DON'T GET TAGGED"
REFERENCE_TEXT = "DON'T GET TAGGED"
COLOR = sys.argv[3] if len(sys.argv) > 3 else "red"


def main() -> None:
    font_size = 400
    while True:
        font = ImageFont.truetype(str(FONT), font_size)
        measure = ImageDraw.Draw(Image.new("L", (1, 1)))
        reference_bounds = measure.textbbox((0, 0), REFERENCE_TEXT, font=font)
        title_bounds = measure.textbbox((0, 0), TEXT, font=font)
        if max(reference_bounds[2] - reference_bounds[0], title_bounds[2] - title_bounds[0]) <= SIZE[0] - 220:
            break
        font_size -= 2

    center = (SIZE[0] // 2, SIZE[1] // 2 - 8)
    canvas = Image.new("RGBA", SIZE)

    shadow_color = "#123619" if COLOR == "green" else "#35100D"
    shadow = Image.new("RGBA", SIZE)
    ImageDraw.Draw(shadow).text(
        (center[0] + 18, center[1] + 25), TEXT, font=font,
        anchor="mm", fill=shadow_color, stroke_width=34, stroke_fill=shadow_color,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(13))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)
    draw.text(center, TEXT, font=font, anchor="mm",
              fill="#24120E", stroke_width=30, stroke_fill="#24120E")
    draw.text(center, TEXT, font=font, anchor="mm",
              fill="#FFE5A6", stroke_width=12, stroke_fill="#FFE5A6")

    letters = Image.new("L", SIZE)
    ImageDraw.Draw(letters).text(center, TEXT, font=font, anchor="mm", fill=255)
    gradient = Image.new("RGBA", SIZE)
    gradient_draw = ImageDraw.Draw(gradient)
    top, bottom = ((92, 224, 78), (18, 139, 51)) if COLOR == "green" else ((255, 75, 43), (220, 19, 16))
    for y in range(SIZE[1]):
        t = y / max(1, SIZE[1] - 1)
        color = (
            round(top[0] + (bottom[0] - top[0]) * t),
            round(top[1] + (bottom[1] - top[1]) * t),
            round(top[2] + (bottom[2] - top[2]) * t),
            255,
        )
        gradient_draw.line((0, y, SIZE[0], y), fill=color)
    canvas.alpha_composite(Image.composite(gradient, Image.new("RGBA", SIZE), letters))
    canvas.save(OUTPUT, optimize=True)


if __name__ == "__main__":
    main()
