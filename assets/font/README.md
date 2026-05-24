# Good Friends History Font POC

This folder contains a caps-only proof-of-concept font generated from
`assets/history-header-trimmed.png`.

- `pngs/`: per-letter source crops, cleaned PNG masks, and PBM inputs for Potrace.
- `vectors/`: Potrace-generated SVG outlines for each supported letter.
- `GoodFriendsHistoryPOC.ttf` and `GoodFriendsHistoryPOC.woff2`: generated font files.
- `index.html` and `test.css`: local browser test sheet.

Regenerate everything with:

```sh
python3 assets/font/generate_history_font.py
```

View the test sheet with:

```sh
python3 -m http.server 8765 --directory assets/font
```

Then open `http://localhost:8765/index.html`.
