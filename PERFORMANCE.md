# Performance Audit

A review of the AEyeverse static gallery (served via GitHub Pages) with prioritized
recommendations. Items marked **[done]** are implemented; **[deferred]** items are intentionally
left for later.

## TL;DR

The page is functionally a single screen that originally referenced **~341 MB of media**.
The dominant cost was image/video weight, not code. The grid now serves responsive AVIF/WebP
thumbnails (rendered incrementally), and the lightbox serves full-size AVIF/WebP / re-encoded
MP4s.

| Asset class | Count | Source size | Optimized |
| --- | --- | --- | --- |
| PNG | 77 | ~250 MB | thumb AVIF ~20–40 KB (400px), full AVIF ~150–250 KB |
| GIF | 3 | ~33 MB | lossy animated WebP (`11.gif` 18.7 MB → 10.7 MB) |
| MP4 | 2 | ~45 MB | `73.mp4` 36 MB → 20 MB (faststart) |
| **Source `images/`** | | **341 MB** | derivatives ~124 MB total, served on demand |

## 1. Oversized images → responsive AVIF/WebP — **[done]**

Grid items are never displayed larger than 400 px, yet the source PNGs were 1664–2048 px and
2–8 MB. `scripts/optimize-images.sh` now generates, per still image:

- `images/thumbs/<n>-400.{webp,avif}` and `images/thumbs/<n>-800.{webp,avif}` — grid (1x/2x)
- `images/full/<n>.{webp,avif}` — lightbox

`script.js` (`USE_OPTIMIZED_ASSETS = true`) serves them via `<picture>` with an AVIF source,
a WebP source, and a WebP `<img>` fallback. Example (`1.png`, 3.1 MB source): 400 px AVIF
**23 KB**, 800 px AVIF 71 KB, full AVIF 238 KB.

## 2. Responsive `srcset` / `sizes` — **[done]**

Each `<source>` exposes `400w` + `800w` candidates with `sizes="(max-width: 600px) 50vw,
200px"`, so the browser downloads the smallest image that fits the slot and device DPR.

## 3. AVIF with WebP fallback — **[done]**

AVIF is offered first (consistently ~15–25% smaller than WebP here), WebP second, and a WebP
`<img>` as the universal fallback — all via native `<picture>` negotiation.

## 4. Incremental (virtualized) grid rendering — **[done]**

The grid renders in batches of 24 via a DocumentFragment, with an `IntersectionObserver`
sentinel (600 px rootMargin) pulling in the next batch as the user scrolls. Browsers without
`IntersectionObserver` fall back to rendering everything. This keeps the initial DOM small as
the collection grows beyond the current 80 items.

## 5. Heavy GIFs and the large MP4 — **[done]**

GIFs are re-encoded to **lossy** animated WebP (`11.gif` 18.7 MB → 10.7 MB). `73.mp4`
(36 MB) → 20 MB and `57.mp4` (6 MB) → 3 MB via H.264 CRF 26 + `-movflags +faststart`. The
lightbox uses `preload="metadata"` and points at the re-encoded `images/full/*.mp4`.

## 6. Corrupt source asset `images/38.png` — **[resolved]**

Originally truncated/corrupt; replaced with a clean 1664×1664 original and regenerated. The
optimizer also gained a Pillow-based truncated-PNG recovery fallback so one bad source can't
abort the batch.

## 7. Render-blocking font, DOM thrashing, CLS, script, metadata — **[done]**

- Removed the render-blocking unused `VT323` Google Fonts `@import`.
- Grid built off-DOM (DocumentFragment) — one reflow per batch.
- Eager-load + `fetchPriority=high` for the first row, lazy/low otherwise; `decoding=async`;
  `content-visibility: auto` + `contain-intrinsic-size`.
- Explicit `width/height` + CSS `aspect-ratio: 1 / 1` to remove layout shift.
- `script.js` is `defer`-loaded; `metadata/<n>.json` responses are cached in-memory.

## 8. Unused assets removed — **[done]**

Deleted the unreferenced `x-logo.png` and the `display:none` social-icons block (and its
`opensea-logo.png` / `magiceden-logo.png`, which were only used by that hidden block) along
with the now-dead `.social-icon*` CSS.

## 9. Caching headers / CDN — **[deferred]**

GitHub Pages sets a short `Cache-Control`. Putting a CDN in front, or moving large media to
object storage with long-lived immutable caching, would improve repeat visits. Intentionally
left for a later decision.

## How to (re)generate optimized assets

```bash
# Requires libwebp (cwebp/gif2webp), libavif-bin (avifenc), ffmpeg, and python3+Pillow (PNG recovery)
./scripts/optimize-images.sh
# USE_OPTIMIZED_ASSETS is already true in script.js
```
