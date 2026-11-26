from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CONTACTS = [
    ("b0000000-0000-4000-8000-000000000001", "Acharya Rahul Sharma", (109, 40, 217), (167, 139, 250)),
    ("b0000000-0000-4000-8000-000000000002", "Pandit Amit Joshi", (124, 58, 237), (196, 181, 253)),
    ("b0000000-0000-4000-8000-000000000003", "Acharya Vikram Mishra", (91, 33, 182), (167, 139, 250)),
    ("b0000000-0000-4000-8000-000000000004", "Pandit Rohan Tiwari", (76, 29, 149), (196, 181, 253)),
    ("b0000000-0000-4000-8000-000000000005", "Acharya Suresh Pandey", (109, 40, 217), (233, 213, 255)),
    ("b0000000-0000-4000-8000-000000000006", "Jyotish Neha Verma", (192, 38, 211), (244, 114, 182)),
    ("b0000000-0000-4000-8000-000000000007", "Pandit Mohan Shastri", (194, 65, 12), (251, 191, 36)),
    ("b0000000-0000-4000-8000-000000000008", "Pandit Rajesh Tiwari", (154, 52, 18), (253, 186, 116)),
    ("b0000000-0000-4000-8000-000000000009", "Pandit Sunil Sharma", (180, 83, 9), (252, 211, 77)),
    ("b0000000-0000-4000-8000-000000000010", "Pandit Anil Tripathi", (194, 65, 12), (254, 215, 170)),
    ("b0000000-0000-4000-8000-000000000011", "Pandit Deepak Mishra", (124, 45, 18), (253, 186, 116)),
    ("b0000000-0000-4000-8000-000000000012", "Pandit Ramesh Dubey", (154, 52, 18), (251, 191, 36)),
    ("b0000000-0000-4000-8000-000000000013", "Numerologist Kavita Rao", (15, 118, 110), (45, 212, 191)),
    ("b0000000-0000-4000-8000-000000000014", "Acharya Manish Gupta", (19, 78, 74), (94, 234, 212)),
    ("b0000000-0000-4000-8000-000000000015", "Jyotish Priya Nair", (17, 94, 89), (45, 212, 191)),
    ("b0000000-0000-4000-8000-000000000016", "Numerologist Arjun Mehta", (15, 118, 110), (153, 246, 228)),
    ("b0000000-0000-4000-8000-000000000017", "Guru Seema Kapoor", (13, 148, 136), (45, 212, 191)),
    ("b0000000-0000-4000-8000-000000000018", "Numerologist Vivek Shah", (15, 118, 110), (94, 234, 212)),
]


def main() -> None:
    out_dir = Path(__file__).resolve().parents[1] / "uploads" / "astrology-contacts"
    out_dir.mkdir(parents=True, exist_ok=True)
    for contact_id, name, c1, c2 in CONTACTS:
        img = Image.new("RGB", (640, 800), c1)
        draw = ImageDraw.Draw(img)
        for y in range(800):
            t = y / 799
            col = tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))
            draw.line([(0, y), (640, y)], fill=col)
        overlay = Image.new("RGBA", (640, 800), (0, 0, 0, 0))
        ImageDraw.Draw(overlay).ellipse((70, 80, 570, 580), fill=(255, 255, 255, 38))
        img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
        draw = ImageDraw.Draw(img)
        initial = name.strip()[:1].upper()
        try:
            font = ImageFont.truetype("arial.ttf", 220)
            nfont = ImageFont.truetype("arial.ttf", 28)
        except Exception:
            font = ImageFont.load_default()
            nfont = font
        bbox = draw.textbbox((0, 0), initial, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(((640 - tw) / 2, 220 - th / 2), initial, fill=(255, 255, 255), font=font)
        draw.rounded_rectangle((40, 640, 600, 760), radius=28, fill=(15, 23, 42))
        short = name if len(name) < 28 else name[:26] + "…"
        nb = draw.textbbox((0, 0), short, font=nfont)
        nw = nb[2] - nb[0]
        draw.text(((640 - nw) / 2, 680), short, fill=(255, 255, 255), font=nfont)
        path = out_dir / f"{contact_id}.png"
        img.save(path)
        print(path)


if __name__ == "__main__":
    main()
