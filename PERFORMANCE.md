# Performance Audit

A review of the AEyeverse static gallery (served via GitHub Pages) with prioritized
recommendations. Items marked **[done]** are implemented in this branch; the rest are
recommendations that require regenerating binary assets or maintainer decisions.

## TL;DR

The page is functionally a single screen that eagerly references **~341 MB of media**.
The dominant cost is image/video weight, not code. The code-level fixes here improve
rendering and reduce layout shift, but the biggest win — by an order of magnitude — is
serving appropriately sized, modern-format images.

| Asset class | Count | Size | Notes |
| --- | --- | --- | --- |
| PNG | 77 | ~250 MB | 1664×1664–2048×2048, 2–8 MB each |
| GIF | 3 | ~33 MB | up to 19 MB (`11.gif`) |
| MP4 | 2 | ~45 MB | `73.mp4` is 38 MB |
| **Total `images/`** | | **341 MB** | |

## 1. Oversized images are the #1 problem (highest impact)

Grid items are never displayed larger than **400 px** (≈800 px on retina), yet the source
PNGs are **1664–2048 px** and 2–8 MB. Every visitor downloads full-resolution masters just
to see 150–400 px thumbnails.

**Recommendations**

- **Generate downscaled thumbnails** (≈800 px) for the grid and reserve full-size only for
  the lightbox. See `scripts/optimize-images.sh`.
- **Switch PNG → WebP (or AVIF)**. For this kind of artwork WebP typically cuts size by
  **70–90%** at visually identical quality. AVIF goes further still.
- After running the script, set `USE_OPTIMIZED_ASSETS = true` in `script.js` to serve
  `images/thumbs/*.webp` in the grid and `images/full/*.webp` in the lightbox.
- For maximum compatibility, serve via `<picture>` with a PNG fallback, or rely on the fact
  that WebP is supported by all current browsers.

Estimated effect: first-load transfer for the grid drops from **hundreds of MB to a few MB**.

## 2. Heavy GIFs and an un-throttled MP4

- `11.gif` (19 MB) and `14.gif` (9.5 MB) are enormous. Animated GIF is an inefficient
  format — converting to **animated WebP** or a muted autoplaying `<video>` (MP4/WebM) is
  typically **5–10× smaller**.
- `73.mp4` (38 MB) is only loaded on lightbox open (good), and now uses `preload="metadata"`
  **[done]** so the full clip isn't fetched until playback. Re-encoding with H.264 CRF ~26 +
  `-movflags +faststart` (in the script) will shrink it substantially and enable streaming.

## 3. Render-blocking, unused web font **[done]**

`style.css` imported `VT323` from Google Fonts via `@import`, which is render-blocking and
triggers extra DNS/TLS/round-trips — but the font was never used (`body` is `Arial`). Removed.

## 4. Grid construction & DOM thrashing **[done]**

The grid was appended one node at a time to the live DOM (up to ~80 layout recalculations).
Now built in a `DocumentFragment` and attached once (a single reflow).

## 5. Loading priorities & lazy loading **[done]**

- Native `loading="lazy"` was already present; we now **eager-load the first row** and set
  `fetchPriority` high/low so above-the-fold paints fast while the rest defer.
- Added `decoding="async"` so image decode doesn't block the main thread.
- Added `content-visibility: auto` + `contain-intrinsic-size` so off-screen grid items skip
  layout/paint work.

## 6. Cumulative Layout Shift (CLS) **[done]**

Grid images had no dimensions, so the page reflowed as each image arrived. Added explicit
`width/height` attributes and a CSS `aspect-ratio: 1 / 1` (all assets are square) to reserve
space up front.

## 7. Script loading **[done]**

`script.js` now uses `defer` so it doesn't block HTML parsing.

## 8. Repeated metadata fetches **[done]**

Opening the same lightbox item refetched its `metadata/<n>.json` every time. Responses are
now cached in-memory (with failure eviction so retries still work).

## 9. Further opportunities (not yet applied)

- **Caching headers / CDN**: GitHub Pages sets a short `Cache-Control` (~10 min). Putting a
  CDN (e.g. Cloudflare) in front, or moving large media to object storage with long-lived
  immutable caching, would help repeat visits.
- **Responsive `srcset`**: serve multiple thumbnail widths and let the browser pick.
- **Pagination / virtualization**: if the collection grows well beyond 80 items, render the
  grid incrementally (e.g. IntersectionObserver) instead of all at once.
- **Unused assets**: `x-logo.png` (27 KB) is committed but not referenced by `index.html`;
  the social-icons block is `display:none`. Remove or wire them up to avoid shipping dead
  weight (they aren't requested by the browser today, but they bloat the repo/clone).

## How to apply the asset optimizations

```bash
# Requires libwebp (cwebp/gif2webp) and optionally ffmpeg + ImageMagick
./scripts/optimize-images.sh
# then edit script.js:
#   const USE_OPTIMIZED_ASSETS = true;
```
