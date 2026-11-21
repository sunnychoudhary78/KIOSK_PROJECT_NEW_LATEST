from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

out = Path(__file__).resolve().parent
out.mkdir(parents=True, exist_ok=True)


def font(size: int) -> ImageFont.ImageFont:
    for name in (
        r"C:\Windows\Fonts\segoeuib.ttf",
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw_gradient(img: Image.Image, c1: tuple[int, int, int], c2: tuple[int, int, int], vertical: bool = False) -> None:
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (y / max(h - 1, 1)) if vertical else (x / max(w - 1, 1))
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)
            px[x, y] = (r, g, b, 255)


# Horizontal top/bottom: 1448 x 180
h_img = Image.new("RGBA", (1448, 180))
draw_gradient(h_img, (225, 29, 72), (147, 51, 234), vertical=False)
overlay = Image.new("RGBA", h_img.size, (255, 255, 255, 0))
od = ImageDraw.Draw(overlay)
od.ellipse((-120, -80, 520, 260), fill=(255, 255, 255, 36))
od.ellipse((980, -40, 1600, 280), fill=(255, 255, 255, 28))
h_img = Image.alpha_composite(h_img, overlay)
d = ImageDraw.Draw(h_img)
title = font(54)
sub = font(28)
d.text((48, 42), "ATHENA  ·  TOP / BOTTOM BANNER", fill=(255, 255, 255, 255), font=title)
d.text((48, 112), "1448 x 180  ·  8:1  ·  replace with your ad creative", fill=(255, 240, 250, 230), font=sub)
d.rectangle((16, 16, 40, 40), outline=(255, 255, 255, 200), width=3)
d.rectangle((1408, 140, 1432, 164), outline=(255, 255, 255, 200), width=3)
h_path = out / "home_banner_horizontal_1448x180.png"
h_img.convert("RGB").save(h_path, "PNG")

# Vertical left/right: 180 x 1086
v_img = Image.new("RGBA", (180, 1086))
draw_gradient(v_img, (2, 132, 199), (124, 58, 237), vertical=True)
overlay = Image.new("RGBA", v_img.size, (255, 255, 255, 0))
od = ImageDraw.Draw(overlay)
od.ellipse((-60, 80, 220, 360), fill=(255, 255, 255, 32))
od.ellipse((-40, 720, 240, 1040), fill=(56, 189, 248, 40))
v_img = Image.alpha_composite(v_img, overlay)

label = Image.new("RGBA", (900, 180), (0, 0, 0, 0))
ld = ImageDraw.Draw(label)
ld.text((20, 40), "ATHENA  ·  LEFT / RIGHT", fill=(255, 255, 255, 255), font=font(42))
ld.text((20, 100), "180 x 1086  ·  ~1:6  ·  test creative", fill=(230, 245, 255, 230), font=font(24))
rotated = label.rotate(90, expand=True)
vx = (180 - rotated.width) // 2
vy = (1086 - rotated.height) // 2
v_img.alpha_composite(rotated, (vx, vy))
d = ImageDraw.Draw(v_img)
d.rectangle((12, 12, 36, 36), outline=(255, 255, 255, 200), width=3)
d.rectangle((144, 1050, 168, 1074), outline=(255, 255, 255, 200), width=3)
v_path = out / "home_banner_vertical_180x1086.png"
v_img.convert("RGB").save(v_path, "PNG")

print(h_path)
print(v_path)
print("horizontal", Image.open(h_path).size)
print("vertical", Image.open(v_path).size)
