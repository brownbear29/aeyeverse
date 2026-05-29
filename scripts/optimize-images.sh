#!/usr/bin/env bash
#
# optimize-images.sh
# ------------------
# Generates optimized, web-ready derivatives of the source assets in `images/`.
#
# The source PNGs are 1664x1664 / 2048x2048 and 2-8 MB each, yet the grid never
# displays them larger than 400px (≈800px on retina). This script produces:
#
#   images/thumbs/<n>.webp   ->  800px-wide WebP thumbnails for the grid
#   images/full/<n>.webp     ->  full-size WebP for the lightbox (lossy q82)
#
# Originals in images/ are never modified, so nothing is lost.
#
# Requirements (install whichever you have):
#   - ImageMagick (`convert` or `magick`)  for PNG/GIF resizing
#   - cwebp / gif2webp (libwebp)           for WebP encoding
#   - ffmpeg                               for optional MP4 re-encode
#
# Usage:
#   ./scripts/optimize-images.sh
#
set -euo pipefail

SRC_DIR="images"
THUMB_DIR="images/thumbs"
FULL_DIR="images/full"
THUMB_WIDTH=800        # 2x the 400px display size for retina screens
FULL_QUALITY=82
THUMB_QUALITY=78

command -v cwebp >/dev/null 2>&1 || { echo "cwebp not found. Install libwebp (e.g. 'apt-get install webp')." >&2; exit 1; }
HAVE_GIF2WEBP=$(command -v gif2webp >/dev/null 2>&1 && echo yes || echo no)

mkdir -p "$THUMB_DIR" "$FULL_DIR"

shopt -s nullglob

echo "Generating WebP derivatives from $SRC_DIR ..."

for src in "$SRC_DIR"/*.png; do
    base="$(basename "${src%.png}")"
    # Full-size WebP for the lightbox.
    cwebp -quiet -q "$FULL_QUALITY" "$src" -o "$FULL_DIR/$base.webp"
    # Downscaled thumbnail for the grid.
    cwebp -quiet -q "$THUMB_QUALITY" -resize "$THUMB_WIDTH" 0 "$src" -o "$THUMB_DIR/$base.webp"
    echo "  png  $base -> thumb + full"
done

if [ "$HAVE_GIF2WEBP" = "yes" ]; then
    for src in "$SRC_DIR"/*.gif; do
        base="$(basename "${src%.gif}")"
        gif2webp -quiet -q "$FULL_QUALITY" "$src" -o "$FULL_DIR/$base.webp"
        gif2webp -quiet -q "$THUMB_QUALITY" "$src" -o "$THUMB_DIR/$base.webp"
        echo "  gif  $base -> animated webp"
    done
else
    echo "  (skipping GIFs: gif2webp not installed)"
fi

# Optional: re-encode MP4s to a web-friendly H.264 + faststart for streaming.
if command -v ffmpeg >/dev/null 2>&1; then
    for src in "$SRC_DIR"/*.mp4; do
        base="$(basename "${src%.mp4}")"
        ffmpeg -y -loglevel error -i "$src" \
            -vf "scale='min(1280,iw)':-2" \
            -c:v libx264 -crf 26 -preset slow -movflags +faststart \
            -c:a aac -b:a 128k \
            "$FULL_DIR/$base.mp4"
        echo "  mp4  $base -> re-encoded (faststart)"
    done
else
    echo "  (skipping MP4s: ffmpeg not installed)"
fi

echo "Done. Review images/thumbs and images/full, then point the grid at the thumbnails."
