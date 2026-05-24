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
from PIL import Image


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT.parent
SOURCE = ASSETS / "history-header-trimmed.png"
WORD = "HISTORY"
FONT_NAME = "GoodFriendsHistoryPOC"
PNGS = ROOT / "pngs"
VECTORS = ROOT / "vectors"
UNITS_PER_EM = 1000
ASCENT = 850
DESCENT = -150
TRACE_THRESHOLD = 32


def tight_bbox(alpha: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(alpha > 8)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def segment_letters(alpha: np.ndarray) -> list[tuple[int, int]]:
    column_has_ink = (alpha > 8).any(axis=0)
    runs: list[tuple[int, int]] = []
    start = None
    for index, has_ink in enumerate(column_has_ink):
        if has_ink and start is None:
            start = index
        elif not has_ink and start is not None:
            runs.append((start, index))
            start = None
    if start is not None:
        runs.append((start, len(column_has_ink)))

    # Merge tiny specks into their neighbors before assigning letters.
    wide_runs = [run for run in runs if run[1] - run[0] > 8]
    if len(wide_runs) == len(WORD):
        return wide_runs

    # If letter art touches, split at the deepest projection valleys.
    projection = alpha.sum(axis=0).astype(float)
    x0, _, x1, _ = tight_bbox(alpha)
    width = x1 - x0
    cut_candidates = []
    for i in range(1, len(WORD)):
        ideal = x0 + round(width * i / len(WORD))
        window = range(max(x0 + 8, ideal - 55), min(x1 - 8, ideal + 55))
        cut = min(window, key=lambda x: projection[x])
        cut_candidates.append(cut)

    cuts = [x0, *sorted(cut_candidates), x1]
    return [(cuts[i], cuts[i + 1]) for i in range(len(WORD))]


def crop_letter(source: Image.Image, span: tuple[int, int]) -> Image.Image:
    alpha = np.array(source.getchannel("A"))
    left, right = span
    slab = alpha[:, max(0, left - 12) : min(alpha.shape[1], right + 12)]
    _, top, _, bottom = tight_bbox(slab)
    crop = source.crop((max(0, left - 12), top, min(alpha.shape[1], right + 12), bottom))
    return crop


def save_glyph_images(source: Image.Image) -> dict[str, Image.Image]:
    PNGS.mkdir(exist_ok=True)
    alpha = np.array(source.getchannel("A"))
    spans = segment_letters(alpha)
    letters: dict[str, Image.Image] = {}
    for letter, span in zip(WORD, spans):
        glyph = crop_letter(source, span)
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
    for letter in WORD:
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
    glyph_order = [".notdef", "space", *WORD]
    glyphs = {".notdef": empty_glyph(), "space": empty_glyph()}
    metrics = {".notdef": (500, 0), "space": (360, 0)}
    cmap = {32: "space"}

    for letter in WORD:
        glyph, advance = glyph_from_svg(VECTORS / f"{letter}.svg")
        glyphs[letter] = glyph
        metrics[letter] = (advance, 0)
        cmap[ord(letter)] = letter
        cmap[ord(letter.lower())] = letter

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
    (ROOT / "test.css").write_text(
        f"""@font-face {{
  font-family: "{FONT_NAME}";
  src: url("./{FONT_NAME}.woff2") format("woff2"),
       url("./{FONT_NAME}.ttf") format("truetype");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
  unicode-range: U+0020, U+0048, U+0049, U+004F, U+0052, U+0053, U+0054, U+0059, U+0068, U+0069, U+006F, U+0072, U+0073, U+0074, U+0079;
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
      <h1>HISTORY</h1>
      <div class="sample">HISTORY history</div>
      <section class="grid" aria-label="Uppercase letters and numbers">
        {"".join(f'<div class="cell{" fallback" if char not in WORD else ""}">{char}</div>' for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}
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
