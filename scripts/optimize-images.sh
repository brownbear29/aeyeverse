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
#   - cwebp / gif2webp (libwebp)           for WebP encoding
#   - python3 + Pillow                     optional fallback for truncated PNGs
#   - ffmpeg                               for optional MP4 re-encode
#
# Usage:
#   ./scripts/optimize-images.sh
#
# The run continues past individual failures and prints a summary at the end, so
# one corrupt source file won't abort the whole batch.
#
set -uo pipefail

SRC_DIR="images"
THUMB_DIR="images/thumbs"
FULL_DIR="images/full"
THUMB_WIDTH=800        # 2x the 400px display size for retina screens
FULL_QUALITY=82
THUMB_QUALITY=78

command -v cwebp >/dev/null 2>&1 || { echo "cwebp not found. Install libwebp (e.g. 'apt-get install webp')." >&2; exit 1; }
HAVE_GIF2WEBP=$(command -v gif2webp >/dev/null 2>&1 && echo yes || echo no)
HAVE_PIL=$(python3 -c "import PIL" >/dev/null 2>&1 && echo yes || echo no)

mkdir -p "$THUMB_DIR" "$FULL_DIR"
shopt -s nullglob

failures=()

# Re-decode a problematic PNG via Pillow (tolerates truncated files) into a temp
# PNG, then hand that to cwebp. Returns non-zero if Pillow isn't available/usable.
recover_png() {
    local src="$1" out="$2"
    [ "$HAVE_PIL" = "yes" ] || return 1
    python3 - "$src" "$out" <<'PY'
import sys
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src); im.load()
im.save(out)
PY
}

echo "Generating WebP derivatives from $SRC_DIR ..."

for src in "$SRC_DIR"/*.png; do
    base="$(basename "${src%.png}")"
    if cwebp -quiet -q "$FULL_QUALITY" "$src" -o "$FULL_DIR/$base.webp" 2>/dev/null \
        && cwebp -quiet -q "$THUMB_QUALITY" -resize "$THUMB_WIDTH" 0 "$src" -o "$THUMB_DIR/$base.webp" 2>/dev/null; then
        echo "  png  $base -> thumb + full"
        continue
    fi

    # cwebp couldn't read it (e.g. truncated PNG); try a Pillow recovery pass.
    tmp="$(mktemp --suffix=.png)"
    if recover_png "$src" "$tmp" \
        && cwebp -quiet -q "$FULL_QUALITY" "$tmp" -o "$FULL_DIR/$base.webp" 2>/dev/null \
        && cwebp -quiet -q "$THUMB_QUALITY" -resize "$THUMB_WIDTH" 0 "$tmp" -o "$THUMB_DIR/$base.webp" 2>/dev/null; then
        echo "  png  $base -> thumb + full (RECOVERED via Pillow; source may be truncated)"
        failures+=("$base.png (decoded only via truncated-image recovery — source likely corrupt)")
    else
        echo "  png  $base -> FAILED to decode" >&2
        failures+=("$base.png (could not decode at all)")
    fi
    rm -f "$tmp"
done

if [ "$HAVE_GIF2WEBP" = "yes" ]; then
    for src in "$SRC_DIR"/*.gif; do
        base="$(basename "${src%.gif}")"
        if gif2webp -quiet -q "$FULL_QUALITY" "$src" -o "$FULL_DIR/$base.webp" 2>/dev/null \
            && gif2webp -quiet -q "$THUMB_QUALITY" "$src" -o "$THUMB_DIR/$base.webp" 2>/dev/null; then
            echo "  gif  $base -> animated webp"
        else
            echo "  gif  $base -> FAILED" >&2
            failures+=("$base.gif")
        fi
    done
else
    echo "  (skipping GIFs: gif2webp not installed)"
fi

# Optional: re-encode MP4s to a web-friendly H.264 + faststart for streaming.
if command -v ffmpeg >/dev/null 2>&1; then
    for src in "$SRC_DIR"/*.mp4; do
        base="$(basename "${src%.mp4}")"
        if ffmpeg -y -loglevel error -i "$src" \
            -vf "scale='min(1280,iw)':-2" \
            -c:v libx264 -crf 26 -preset slow -movflags +faststart \
            -c:a aac -b:a 128k \
            "$FULL_DIR/$base.mp4" 2>/dev/null; then
            echo "  mp4  $base -> re-encoded (faststart)"
        else
            echo "  mp4  $base -> FAILED" >&2
            failures+=("$base.mp4")
        fi
    done
else
    echo "  (skipping MP4s: ffmpeg not installed)"
fi

echo ""
if [ "${#failures[@]}" -eq 0 ]; then
    echo "Done with no errors. Review images/thumbs and images/full, then set USE_OPTIMIZED_ASSETS=true."
else
    echo "Done, but the following sources need attention:"
    for f in "${failures[@]}"; do echo "  - $f"; done
fi
