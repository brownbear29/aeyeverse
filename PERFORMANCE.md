# Performance Audit

A review of the AEyeverse static gallery (served via GitHub Pages) with prioritized
recommendations. Items marked **[done]** are implemented; **[needs action]** items require a
maintainer decision or a clean source asset.

## TL;DR

The page is functionally a single screen that originally referenced **~341 MB of media**.
The dominant cost was image/video weight, not code. Both layers are now addressed: the grid
serves lightweight WebP thumbnails and the lightbox serves full-size WebP / re-encoded MP4s.

| Asset class | Count | Source size | Optimized |
| --- | --- | --- | --- |
| PNG | 77 | ~250 MB | thumbs ~50–85 KB each, full ~200–500 KB |
| GIF | 3 | ~33 MB | animated WebP |
| MP4 | 2 | ~45 MB | `73.mp4` 36 MB → 20 MB (faststart) |
| **Source `images/`** | | **341 MB** | grid thumbs total **~31 MB**, lazy-loaded |

## 1. Oversized images — **[done]**

Grid items are never displayed larger than 400 px, yet the source PNGs were 1664–2048 px and
2–8 MB. `scripts/optimize-images.sh` now generates:

- `images/thumbs/<n>.webp` — 800 px WebP grid thumbnails
- `images/full/<n>.webp` — full-size WebP for the lightbox (q82)

`script.js` sets `USE_OPTIMIZED_ASSETS = true` to serve them. Representative reductions:
`13.png` 6.6 MB → **66 KB** thumb / 485 KB full; `1.png` 3.1 MB → **83 KB** thumb.

## 2. Heavy GIFs and the large MP4 — **[done]**

- The three GIFs are re-encoded to animated WebP.
- `73.mp4` (36 MB) → **20 MB** and `57.mp4` (6 MB) → 3 MB via H.264 CRF 26 + `-movflags
  +faststart` (streamable). The lightbox uses `preload="metadata"` so clips aren't fetched
  until playback, and now points at the re-encoded `images/full/*.mp4`.

## 3. Corrupt source asset: `images/38.png` — **[needs action]**

`38.png` is **truncated/corrupt** — `cwebp` and `ffmpeg` both reject it ("chunk too big" /
read overflow), and an image upload of the same 2,370,957-byte file also failed to decode.
Its bottom ~9% (≈ rows 1518–1664) is missing. The optimizer produced a best-effort WebP via
a truncated-image recovery pass, so the gallery isn't broken, **but it shows a black bar at
the bottom**. Action: replace `images/38.png` with a clean original and re-run the optimizer
(or just regenerate `38`).

## 4. Render-blocking, unused web font — **[done]**

Removed the render-blocking `VT323` Google Fonts `@import` (the site uses Arial).

## 5. Grid construction & DOM thrashing — **[done]**

Grid is built in a `DocumentFragment` and attached once (single reflow instead of ~80).

## 6. Loading priorities & lazy loading — **[done]**

Eager-load + `fetchPriority=high` for the first row, lazy/low for the rest; `decoding=async`;
`content-visibility: auto` + `contain-intrinsic-size` to skip off-screen work.

## 7. Cumulative Layout Shift (CLS) — **[done]**

Explicit `width/height` on grid images + CSS `aspect-ratio: 1 / 1` (assets are square).

## 8. Script loading — **[done]**

`script.js` uses `defer` so it no longer blocks HTML parsing.

## 9. Repeated metadata fetches — **[done]**

`metadata/<n>.json` responses are cached in-memory (with failure eviction for retries).

## 10. Further opportunities (not yet applied)

- **Caching headers / CDN**: GitHub Pages sets a short `Cache-Control`. A CDN in front, or
  moving large media to object storage with long-lived immutable caching, helps repeat visits.
- **AVIF**: encode AVIF alongside WebP for another ~20–30% on top, served via `<picture>`.
- **Responsive `srcset`**: serve multiple thumbnail widths and let the browser choose.
- **Pagination / virtualization** if the collection grows well beyond 80 items.
- **Unused assets**: `x-logo.png` (27 KB) is committed but unreferenced; the social-icons
  block is `display:none`. Remove or wire them up.

## How to (re)generate optimized assets

```bash
# Requires libwebp (cwebp/gif2webp); ffmpeg for MP4; python3 + Pillow as a PNG-recovery fallback
./scripts/optimize-images.sh
# USE_OPTIMIZED_ASSETS is already true in script.js
```
