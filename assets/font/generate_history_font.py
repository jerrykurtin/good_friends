from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

import numpy as np
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT.parent
SOURCE = ASSETS / "history-header-trimmed.png"
GLYPHS = ["H", "i", "S", "T", "o", "R", "Y"]
DISPLAY_WORD = "HiSToRY"
FONT_NAME = "GoodFriendsHistoryPOC"
PNGS = ROOT / "pngs"
VECTORS = ROOT / "vectors"
UNITS_PER_EM = 1000
ASCENT = 850
DESCENT = -150
TRACE_THRESHOLD = 32


def clean_generated_outputs() -> None:
    for folder in [PNGS, VECTORS]:
        folder.mkdir(exist_ok=True)
        for path in folder.iterdir():
            if path.suffix.lower() in {".png", ".pbm", ".svg"}:
                path.unlink()


def tight_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.array(image.getchannel("A"))
    ys, xs = np.where(alpha > 8)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def region_mask(size: tuple[int, int], shapes: list[tuple[str, tuple]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for kind, coords in shapes:
        if kind == "rect":
            draw.rectangle(coords, fill=255)
        elif kind == "poly":
            draw.polygon(coords, fill=255)
        else:
            raise ValueError(f"Unsupported mask shape {kind}")
    return mask


def glyph_regions(size: tuple[int, int]) -> dict[str, Image.Image]:
    w, h = size
    return {
        "H": region_mask(size, [("rect", (0, 0, 451, h))]),
        "i": region_mask(size, [("rect", (451, 0, 592, h))]),
        "S": region_mask(
            size,
            [
                ("poly", [(592, 0), (852, 0), (890, 170), (910, h), (592, h)]),
            ],
        ),
        "T": region_mask(
            size,
            [
                ("poly", [(850, 0), (1168, 0), (1168, 96), (1090, 175), (850, 175)]),
                ("poly", [(925, 130), (1085, 130), (1095, h), (900, h)]),
            ],
        ),
        "o": region_mask(size, [("rect", (1110, 0, 1384, h))]),
        "R": region_mask(
            size,
            [
                ("poly", [(1410, 0), (1688, 0), (1704, h), (1410, h)]),
            ],
        ),
        "Y": region_mask(
            size,
            [
                ("poly", [(1710, 0), (w, 0), (w, h), (1720, h), (1716, 245)]),
            ],
        ),
    }


def extract_glyph(source: Image.Image, mask: Image.Image) -> Image.Image:
    masked = Image.new("RGBA", source.size, (255, 255, 255, 0))
    source_alpha = Image.composite(source.getchannel("A"), Image.new("L", source.size, 0), mask)
    masked.paste(source, (0, 0))
    masked.putalpha(source_alpha)
    return masked.crop(tight_bbox(masked))


def keep_largest_components(image: Image.Image, component_count: int) -> Image.Image:
    alpha = np.array(image.getchannel("A"))
    ink = alpha > 8
    seen = np.zeros(ink.shape, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    height, width = ink.shape

    for y in range(height):
        for x in range(width):
            if not ink[y, x] or seen[y, x]:
                continue
            stack = [(x, y)]
            seen[y, x] = True
            component = []
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height and ink[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
            components.append(component)

    keep = sorted(components, key=len, reverse=True)[:component_count]
    component_mask = np.zeros(ink.shape, dtype=np.uint8)
    for component in keep:
        for x, y in component:
            component_mask[y, x] = 255

    cleaned = image.copy()
    cleaned_alpha = Image.fromarray(
        np.where(component_mask, alpha, 0).astype(np.uint8),
        mode="L",
    )
    cleaned.putalpha(cleaned_alpha)
    return cleaned.crop(tight_bbox(cleaned))


def save_glyph_images(source: Image.Image) -> dict[str, Image.Image]:
    clean_generated_outputs()
    regions = glyph_regions(source.size)
    letters: dict[str, Image.Image] = {}
    for letter in GLYPHS:
        glyph = extract_glyph(source, regions[letter])
        glyph = keep_largest_components(glyph, 2 if letter == "i" else 1)
        glyph.save(PNGS / f"{letter}.source.png")

        alpha_mask = glyph.getchannel("A")
        ink = alpha_mask.point(lambda p: 255 if p > TRACE_THRESHOLD else 0, mode="L")
        ink.save(PNGS / f"{letter}.png")

        # Potrace wants a 1-bit bitmap. In PBM, black pixels are traced.
        pbm = alpha_mask.point(lambda p: 0 if p > TRACE_THRESHOLD else 255, mode="1")
        pbm.save(PNGS / f"{letter}.pbm")
        letters[letter] = glyph
    return letters


def trace_letters() -> None:
    VECTORS.mkdir(exist_ok=True)
    for letter in GLYPHS:
        subprocess.run(
            [
                "potrace",
                str(PNGS / f"{letter}.pbm"),
                "--svg",
                "--output",
                str(VECTORS / f"{letter}.svg"),
                "--turdsize",
                "18",
                "--alphamax",
                "1.2",
                "--opttolerance",
                "0.18",
            ],
            check=True,
        )


def svg_size(svg_path: Path) -> tuple[float, float]:
    text = svg_path.read_text(encoding="utf-8")
    match = re.search(r'viewBox="0 0 ([0-9.]+) ([0-9.]+)"', text)
    if not match:
        raise ValueError(f"Could not read viewBox from {svg_path}")
    return float(match.group(1)), float(match.group(2))


def svg_paths(svg_path: Path) -> list[str]:
    root = ET.parse(svg_path).getroot()
    return [
        path.attrib["d"]
        for path in root.findall(".//{http://www.w3.org/2000/svg}path")
        if path.attrib.get("d")
    ]


def glyph_from_svg(svg_path: Path):
    width, height = svg_size(svg_path)
    pen = TTGlyphPen(None)
    side_bearing = 55
    scale = ASCENT / height

    # Potrace's SVG path coordinates are 10x the source pixels. Mapping that
    # raw coordinate space directly into font units keeps y-up glyph outlines.
    quadratic_pen = Cu2QuPen(pen, max_err=1.0)
    transform = TransformPen(
        quadratic_pen, (0.1 * scale, 0, 0, 0.1 * scale, side_bearing, 0)
    )
    for path_data in svg_paths(svg_path):
        parse_path(path_data, transform)

    advance = round(side_bearing * 2 + width * scale)
    return pen.glyph(), advance


def empty_glyph():
    return TTGlyphPen(None).glyph()


def build_font(letters: dict[str, Image.Image]) -> None:
    glyph_order = [".notdef", "space", *GLYPHS]
    glyphs = {".notdef": empty_glyph(), "space": empty_glyph()}
    metrics = {".notdef": (500, 0), "space": (360, 0)}
    cmap = {32: "space"}

    for letter in GLYPHS:
        glyph, advance = glyph_from_svg(VECTORS / f"{letter}.svg")
        glyphs[letter] = glyph
        metrics[letter] = (advance, 0)
        for character in {letter, letter.upper(), letter.lower()}:
            cmap[ord(character)] = letter

    fb = FontBuilder(UNITS_PER_EM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupOS2(
        sTypoAscender=ASCENT,
        sTypoDescender=DESCENT,
        usWinAscent=ASCENT,
        usWinDescent=abs(DESCENT),
    )
    fb.setupNameTable(
        {
            "familyName": FONT_NAME,
            "styleName": "Regular",
            "uniqueFontIdentifier": f"{FONT_NAME} Regular",
            "fullName": f"{FONT_NAME} Regular",
            "psName": f"{FONT_NAME}-Regular",
            "version": "Version 0.1",
        }
    )
    fb.setupPost()
    fb.save(ROOT / f"{FONT_NAME}.ttf")

    font = TTFont(ROOT / f"{FONT_NAME}.ttf")
    font.flavor = "woff2"
    font.save(ROOT / f"{FONT_NAME}.woff2")


def write_test_page() -> None:
    supported_chars = "".join(sorted({c for glyph in GLYPHS for c in {glyph, glyph.upper(), glyph.lower()}}))
    unicode_range = ", ".join(f"U+{ord(char):04X}" for char in [" ", *supported_chars])
    (ROOT / "test.css").write_text(
        f"""@font-face {{
  font-family: "{FONT_NAME}";
  src: url("./{FONT_NAME}.woff2") format("woff2"),
       url("./{FONT_NAME}.ttf") format("truetype");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
  unicode-range: {unicode_range};
}}

:root {{
  color-scheme: light;
  --ink: #3a2a1d;
  --paper: #fff8df;
  --accent: #f4b23e;
}}

* {{
  box-sizing: border-box;
}}

body {{
  margin: 0;
  min-height: 100vh;
  background: var(--paper);
  color: var(--ink);
  font-family: "{FONT_NAME}", "Cooper Black", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif;
}}

main {{
  width: min(1100px, calc(100% - 32px));
  margin: 0 auto;
  padding: 40px 0;
}}

h1, .sample, .cell {{
  font-family: "{FONT_NAME}", "Cooper Black", "Arial Rounded MT Bold", "Trebuchet MS", sans-serif;
  font-weight: 900;
  letter-spacing: 0;
}}

h1 {{
  margin: 0 0 24px;
  font-size: 52px;
  line-height: 1;
}}

.sample {{
  margin: 0 0 28px;
  padding: 24px;
  border: 4px solid var(--ink);
  background: #fff;
  font-size: 84px;
  line-height: 1.05;
  overflow-wrap: anywhere;
}}

.grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(72px, 1fr));
  gap: 10px;
}}

.cell {{
  display: grid;
  place-items: center;
  aspect-ratio: 1;
  border: 3px solid var(--ink);
  background: #fff;
  font-size: 42px;
  line-height: 1;
}}

.fallback {{
  background: var(--accent);
}}
""",
        encoding="utf-8",
    )
    (ROOT / "index.html").write_text(
        f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{FONT_NAME} Test</title>
    <link rel="stylesheet" href="./test.css">
  </head>
  <body>
    <main>
      <h1>{DISPLAY_WORD}</h1>
      <div class="sample">HISTORY {DISPLAY_WORD}</div>
      <section class="grid" aria-label="Uppercase letters and numbers">
        {"".join(f'<div class="cell{" fallback" if char not in supported_chars else ""}">{char}</div>' for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}
      </section>
    </main>
  </body>
</html>
""",
        encoding="utf-8",
    )


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    letters = save_glyph_images(source)
    trace_letters()
    build_font(letters)
    write_test_page()


if __name__ == "__main__":
    main()
