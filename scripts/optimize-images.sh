#!/usr/bin/env bash
#
# optimize-images.sh
# ------------------
# Generates optimized, web-ready derivatives of the source assets in `images/`.
#
# Source PNGs are 1664x1664 / 2048x2048 and 2-8 MB each, yet the grid never
# displays them larger than 400px (≈800px on retina). This script produces, for
# each still image, responsive WebP + AVIF derivatives:
#
#   images/thumbs/<n>-400.webp  images/thumbs/<n>-400.avif   (grid, 1x)
#   images/thumbs/<n>-800.webp  images/thumbs/<n>-800.avif   (grid, 2x/retina)
#   images/full/<n>.webp        images/full/<n>.avif         (lightbox)
#
# Animated GIFs become a single lossy animated WebP (animated AVIF is impractical):
#   images/thumbs/<n>.webp      images/full/<n>.webp
#
# MP4s are re-encoded to H.264 + faststart:
#   images/full/<n>.mp4
#
# Originals in images/ are never modified.
#
# Requirements:
#   - cwebp / gif2webp (libwebp)
#   - avifenc (libavif-bin)
#   - ffmpeg (image resizing + MP4 re-encode)
#   - python3 + Pillow (optional fallback for truncated PNGs)
#
# Usage: ./scripts/optimize-images.sh
# The run continues past per-file failures and prints a summary at the end.
#
set -uo pipefail

SRC_DIR="images"
THUMB_DIR="images/thumbs"
FULL_DIR="images/full"
THUMB_WIDTHS=(400 800)
WEBP_FULL_Q=82
WEBP_THUMB_Q=78
AVIF_FULL_Q=62
AVIF_THUMB_Q=55
AVIF_SPEED=6
GIF_WEBP_Q=70

command -v cwebp   >/dev/null 2>&1 || { echo "cwebp not found (apt-get install webp)." >&2; exit 1; }
command -v avifenc >/dev/null 2>&1 || { echo "avifenc not found (apt-get install libavif-bin)." >&2; exit 1; }
command -v ffmpeg  >/dev/null 2>&1 || { echo "ffmpeg not found." >&2; exit 1; }
HAVE_GIF2WEBP=$(command -v gif2webp >/dev/null 2>&1 && echo yes || echo no)
HAVE_PIL=$(python3 -c "import PIL" >/dev/null 2>&1 && echo yes || echo no)

mkdir -p "$THUMB_DIR" "$FULL_DIR"
shopt -s nullglob
failures=()
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Decode a (possibly truncated) PNG into a clean temp PNG via Pillow.
recover_png() {
    [ "$HAVE_PIL" = "yes" ] || return 1
    python3 - "$1" "$2" <<'PY'
import sys
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
im = Image.open(sys.argv[1]); im.load()
im.save(sys.argv[2])
PY
}

# Produce a width-capped (never upscaled) temp PNG. Echoes the temp path.
resized_png() {
    local src="$1" w="$2" out="$TMP/r_${w}_$$.png"
    ffmpeg -y -loglevel error -i "$src" -vf "scale='min($w,iw)':-2:flags=lanczos" "$out" 2>/dev/null || return 1
    echo "$out"
}

encode_still() {
    # $1 = decodable source PNG, $2 = base name (n)
    local src="$1" base="$2"
    # Full-size WebP + AVIF for the lightbox.
    cwebp   -quiet -q "$WEBP_FULL_Q" "$src" -o "$FULL_DIR/$base.webp" 2>/dev/null || return 1
    avifenc -q "$AVIF_FULL_Q" -s "$AVIF_SPEED" "$src" "$FULL_DIR/$base.avif" >/dev/null 2>&1 || return 1
    # Responsive grid thumbnails.
    local w rp
    for w in "${THUMB_WIDTHS[@]}"; do
        rp="$(resized_png "$src" "$w")" || return 1
        cwebp   -quiet -q "$WEBP_THUMB_Q" "$rp" -o "$THUMB_DIR/$base-$w.webp" 2>/dev/null || return 1
        avifenc -q "$AVIF_THUMB_Q" -s "$AVIF_SPEED" "$rp" "$THUMB_DIR/$base-$w.avif" >/dev/null 2>&1 || return 1
        rm -f "$rp"
    done
    return 0
}

echo "Generating derivatives from $SRC_DIR ..."

# --- Still images (PNG, incl. video placeholders) ---
for src in "$SRC_DIR"/*.png; do
    base="$(basename "${src%.png}")"
    if encode_still "$src" "$base"; then
        echo "  png  $base -> webp/avif (full + 400/800)"
        continue
    fi
    # cwebp/avifenc couldn't read it (e.g. truncated PNG); try a Pillow recovery.
    tmp="$TMP/recover_$base.png"
    if recover_png "$src" "$tmp" && encode_still "$tmp" "$base"; then
        echo "  png  $base -> RECOVERED via Pillow (source may be truncated)"
        failures+=("$base.png (decoded only via truncated-image recovery — source likely corrupt)")
    else
        echo "  png  $base -> FAILED to decode" >&2
        failures+=("$base.png (could not decode)")
    fi
    rm -f "$tmp"
done

# --- Animated GIFs -> single lossy animated WebP ---
if [ "$HAVE_GIF2WEBP" = "yes" ]; then
    for src in "$SRC_DIR"/*.gif; do
        base="$(basename "${src%.gif}")"
        if gif2webp -quiet -lossy -q "$GIF_WEBP_Q" -m 6 "$src" -o "$FULL_DIR/$base.webp" 2>/dev/null; then
            cp "$FULL_DIR/$base.webp" "$THUMB_DIR/$base.webp"
            echo "  gif  $base -> animated webp (lossy)"
        else
            echo "  gif  $base -> FAILED" >&2
            failures+=("$base.gif")
        fi
    done
else
    echo "  (skipping GIFs: gif2webp not installed)"
fi

# --- MP4 -> H.264 faststart ---
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

echo ""
if [ "${#failures[@]}" -eq 0 ]; then
    echo "Done with no errors. Set USE_OPTIMIZED_ASSETS=true in script.js."
else
    echo "Done, but the following sources need attention:"
    for f in "${failures[@]}"; do echo "  - $f"; done
fi
