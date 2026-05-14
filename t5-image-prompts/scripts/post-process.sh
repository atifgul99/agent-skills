#!/usr/bin/env bash
# T5 Image Post-Processor — ImageMagick
# Converts, resizes, and processes generated images for production use
#
# Usage:
#   ./post-process.sh --input ./source.png --action resize --width 512 --height 512 --output ./resized.png

set -euo pipefail

# --- Defaults ---
INPUT=""
INPUTS=""
OUTPUT=""
ACTION=""
WIDTH=""
HEIGHT=""
FORMAT=""
QUALITY=85
COLOR=""
FUZZ="10%"
TEXT=""
TILE_SIZE=256
RADIUS=10
ACTIONS=""
OUTPUT_DIR=""
PREFIX=""

# --- Parse Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)      INPUT="$2"; shift 2 ;;
    --inputs)     INPUTS="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --action)     ACTION="$2"; shift 2 ;;
    --width)      WIDTH="$2"; shift 2 ;;
    --height)     HEIGHT="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --quality)    QUALITY="$2"; shift 2 ;;
    --color)      COLOR="$2"; shift 2 ;;
    --fuzz)       FUZZ="$2"; shift 2 ;;
    --text)       TEXT="$2"; shift 2 ;;
    --tile-size)  TILE_SIZE="$2"; shift 2 ;;
    --radius)     RADIUS="$2"; shift 2 ;;
    --actions)    ACTIONS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --prefix)     PREFIX="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: post-process.sh --input ./source.png --action ACTION [options]"
      echo ""
      echo "Actions: resize, convert, favicon, og-image, twitter-card, apple-touch,"
      echo "  pwa-icons, hero, thumbnail, transparency, extract-meta, optimize,"
      echo "  blur, grayscale, watermark, sprite, background, batch"
      echo ""
      echo "Options:"
      echo "  --input PATH       Input image file"
      echo "  --output PATH      Output file path (auto-generated if omitted)"
      echo "  --output-dir DIR   Output directory for multi-file actions"
      echo "  --width N          Width for resize/thumbnail"
      echo "  --height N         Height for resize/thumbnail"
      echo "  --format FMT       Target format: webp, png, jpg, avif, ico, svg, gif"
      echo "  --quality N        Quality 1-100 (default: 85)"
      echo "  --color COLOR      Color for transparency removal"
      echo "  --fuzz PCT         Fuzz tolerance for transparency (default: 10%)"
      echo "  --text TEXT        Watermark text"
      echo "  --tile-size N      Tile size for background (default: 256)"
      echo "  --radius N         Blur radius (default: 10)"
      echo "  --inputs FILES     Comma-separated files for sprite"
      echo "  --actions LIST     Comma-separated actions for batch"
      exit 0
      ;;
    *)            echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Validate ---
if [[ -z "$ACTION" ]]; then
  echo "Error: --action is required"
  exit 1
fi

if [[ -z "$INPUT" && "$ACTION" != "sprite" ]]; then
  echo "Error: --input is required"
  exit 1
fi

if ! command -v magick &>/dev/null; then
  echo "Error: ImageMagick (magick) not found. Install with: brew install imagemagick"
  exit 1
fi

# --- Helper Functions ---
auto_output() {
  local ext="${1:-png}"
  local base
  base=$(basename "$INPUT" | sed 's/\.[^.]*$//')
  if [[ -n "$OUTPUT_DIR" ]]; then
    echo "${OUTPUT_DIR}/${base}-${ACTION}.${ext}"
  else
    local dir
    dir=$(dirname "$INPUT")
    echo "${dir}/${base}-${ACTION}.${ext}"
  fi
}

get_prefix() {
  if [[ -n "$PREFIX" ]]; then
    echo "$PREFIX"
  else
    basename "$INPUT" | sed 's/\.[^.]*$//'
  fi
}

ensure_dir() {
  local dir
  dir=$(dirname "$1")
  mkdir -p "$dir"
}

report() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local size dims
    size=$(wc -c < "$file" | tr -d ' ')
    dims=$(magick identify -format "%wx%h" "$file" 2>/dev/null || echo "unknown")
    echo "  Created: $file (${dims}, $(( size / 1024 ))KB)"
  fi
}

# --- Actions ---
case "$ACTION" in

  resize)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    GEOMETRY=""
    if [[ -n "$WIDTH" && -n "$HEIGHT" ]]; then
      GEOMETRY="${WIDTH}x${HEIGHT}!"
    elif [[ -n "$WIDTH" ]]; then
      GEOMETRY="${WIDTH}x"
    elif [[ -n "$HEIGHT" ]]; then
      GEOMETRY="x${HEIGHT}"
    else
      echo "Error: --width and/or --height required for resize"; exit 1
    fi
    magick "$INPUT" -resize "$GEOMETRY" -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    ;;

  convert)
    if [[ -z "$FORMAT" ]]; then echo "Error: --format required for convert"; exit 1; fi
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "$FORMAT")
    ensure_dir "$OUTPUT"
    case "$FORMAT" in
      webp)  magick "$INPUT" -quality "$QUALITY" "$OUTPUT" ;;
      avif)  magick "$INPUT" -quality "$QUALITY" "$OUTPUT" ;;
      jpg)   magick "$INPUT" -quality "$QUALITY" -background white -flatten "$OUTPUT" ;;
      png)   magick "$INPUT" -quality "$QUALITY" "$OUTPUT" ;;
      gif)   magick "$INPUT" "$OUTPUT" ;;
      ico)   magick "$INPUT" -resize 256x256 -define icon:auto-resize=256,128,64,48,32,16 "$OUTPUT" ;;
      svg)
        echo "Note: Raster→SVG produces bitmap-embedded SVG (not true vector)."
        _w=$(magick identify -format "%w" "$INPUT")
        _h=$(magick identify -format "%h" "$INPUT")
        _b64=$(base64 < "$INPUT" | tr -d '\n')
        cat > "$OUTPUT" <<SVGEOF
<svg xmlns="http://www.w3.org/2000/svg" width="${_w}" height="${_h}" viewBox="0 0 ${_w} ${_h}">
  <image href="data:image/png;base64,${_b64}" width="${_w}" height="${_h}"/>
</svg>
SVGEOF
        ;;
      *) magick "$INPUT" "$OUTPUT" ;;
    esac
    report "$OUTPUT"
    ;;

  favicon)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")/favicons}"
    mkdir -p "$_outdir"
    echo "Generating favicon set..."
    for size in 16 32 48; do
      magick "$INPUT" -resize "${size}x${size}!" "$_outdir/favicon-${size}x${size}.png"
      report "$_outdir/favicon-${size}x${size}.png"
    done
    magick "$INPUT" -resize "180x180!" "$_outdir/apple-touch-icon.png"
    report "$_outdir/apple-touch-icon.png"
    for size in 192 512; do
      magick "$INPUT" -resize "${size}x${size}!" "$_outdir/icon-${size}x${size}.png"
      report "$_outdir/icon-${size}x${size}.png"
    done
    magick "$INPUT" -resize 256x256 -define icon:auto-resize=256,128,64,48,32,16 "$_outdir/favicon.ico"
    report "$_outdir/favicon.ico"
    echo "Favicon set complete: $_outdir/"
    ;;

  og-image)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    magick "$INPUT" -resize "1200x630^" -gravity center -extent 1200x630 -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    ;;

  twitter-card)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    magick "$INPUT" -resize "1200x600^" -gravity center -extent 1200x600 -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    ;;

  apple-touch)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    magick "$INPUT" -resize "180x180!" -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    ;;

  pwa-icons)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")/pwa-icons}"
    mkdir -p "$_outdir"
    echo "Generating PWA icon set..."
    for size in 72 96 128 144 152 192 384 512; do
      magick "$INPUT" -resize "${size}x${size}!" "$_outdir/icon-${size}x${size}.png"
      report "$_outdir/icon-${size}x${size}.png"
    done
    echo "PWA icon set complete: $_outdir/"
    ;;

  hero)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")/hero}"
    mkdir -p "$_outdir"
    echo "Generating hero image set..."
    magick "$INPUT" -resize "1920x1080^" -gravity center -extent 1920x1080 -quality "$QUALITY" "$_outdir/hero-1920x1080.webp"
    report "$_outdir/hero-1920x1080.webp"
    magick "$INPUT" -resize "1440x810^" -gravity center -extent 1440x810 -quality "$QUALITY" "$_outdir/hero-1440x810.webp"
    report "$_outdir/hero-1440x810.webp"
    magick "$INPUT" -resize "768x432^" -gravity center -extent 768x432 -quality "$QUALITY" "$_outdir/hero-768x432.webp"
    report "$_outdir/hero-768x432.webp"
    magick "$INPUT" -resize "414x736^" -gravity center -extent 414x736 -quality "$QUALITY" "$_outdir/hero-414x736.webp"
    report "$_outdir/hero-414x736.webp"
    echo "Hero set complete: $_outdir/"
    ;;

  thumbnail)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    _tw="${WIDTH:-300}"
    _th="${HEIGHT:-300}"
    magick "$INPUT" -resize "${_tw}x${_th}^" -gravity center -extent "${_tw}x${_th}" -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    ;;

  transparency)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    if [[ -z "$COLOR" ]]; then echo "Error: --color required (e.g., 'white', '#ffffff')"; exit 1; fi
    magick "$INPUT" -fuzz "$FUZZ" -transparent "$COLOR" "$OUTPUT"
    report "$OUTPUT"
    ;;

  extract-meta)
    echo "=== Image Metadata ==="
    magick identify -verbose "$INPUT" 2>/dev/null | head -50
    ;;

  optimize)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "webp")
    ensure_dir "$OUTPUT"
    _ext=$(echo "$OUTPUT" | sed 's/.*\.//')
    case "$_ext" in
      webp) magick "$INPUT" -strip -quality "$QUALITY" "$OUTPUT" ;;
      png)  magick "$INPUT" -strip -quality "$QUALITY" "$OUTPUT" ;;
      jpg)  magick "$INPUT" -strip -interlace Plane -quality "$QUALITY" "$OUTPUT" ;;
      *)    magick "$INPUT" -strip -quality "$QUALITY" "$OUTPUT" ;;
    esac
    _orig_size=$(wc -c < "$INPUT" | tr -d ' ')
    _new_size=$(wc -c < "$OUTPUT" | tr -d ' ')
    if [[ "$_orig_size" -gt 0 ]]; then
      _saved=$(( (_orig_size - _new_size) * 100 / _orig_size ))
    else
      _saved=0
    fi
    echo "Optimized: $(( _orig_size / 1024 ))KB → $(( _new_size / 1024 ))KB (${_saved}% reduction)"
    report "$OUTPUT"
    ;;

  blur)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    magick "$INPUT" -blur "0x${RADIUS}" "$OUTPUT"
    report "$OUTPUT"
    ;;

  grayscale)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    magick "$INPUT" -colorspace Gray "$OUTPUT"
    report "$OUTPUT"
    ;;

  watermark)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    if [[ -z "$TEXT" ]]; then echo "Error: --text required for watermark"; exit 1; fi
    magick "$INPUT" -gravity SouthEast -fill "rgba(255,255,255,0.3)" -pointsize 24 -annotate +10+10 "$TEXT" "$OUTPUT"
    report "$OUTPUT"
    ;;

  sprite)
    if [[ -z "$INPUTS" ]]; then echo "Error: --inputs required for sprite (comma-separated)"; exit 1; fi
    [[ -z "$OUTPUT" ]] && OUTPUT="./sprite.png"
    ensure_dir "$OUTPUT"
    IFS=',' read -ra FILES <<< "$INPUTS"
    magick "${FILES[@]}" +append "$OUTPUT"
    report "$OUTPUT"
    ;;

  background)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    _tile_tmp=$(mktemp /tmp/tile-XXXXXX.png)
    magick "$INPUT" -resize "${TILE_SIZE}x${TILE_SIZE}!" "$_tile_tmp"
    magick \( "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" +append \) \
           \( "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" +append \) \
           \( "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" +append \) \
           \( "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" "$_tile_tmp" +append \) \
           -append "$OUTPUT"
    rm -f "$_tile_tmp"
    report "$OUTPUT"
    ;;

  batch)
    if [[ -z "$ACTIONS" ]]; then echo "Error: --actions required for batch (comma-separated)"; exit 1; fi
    IFS=',' read -ra ACTION_LIST <<< "$ACTIONS"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for act in "${ACTION_LIST[@]}"; do
      act=$(echo "$act" | tr -d ' ')
      echo "--- Running: $act ---"
      BATCH_ARGS=(--input "$INPUT" --action "$act" --quality "$QUALITY")
      [[ -n "$WIDTH" ]] && BATCH_ARGS+=(--width "$WIDTH")
      [[ -n "$HEIGHT" ]] && BATCH_ARGS+=(--height "$HEIGHT")
      [[ -n "$FORMAT" ]] && BATCH_ARGS+=(--format "$FORMAT")
      [[ -n "$OUTPUT_DIR" ]] && BATCH_ARGS+=(--output-dir "$OUTPUT_DIR")
      [[ -n "$COLOR" ]] && BATCH_ARGS+=(--color "$COLOR")
      [[ -n "$TEXT" ]] && BATCH_ARGS+=(--text "$TEXT")
      [[ "$FUZZ" != "10%" ]] && BATCH_ARGS+=(--fuzz "$FUZZ")
      [[ "$TILE_SIZE" != "256" ]] && BATCH_ARGS+=(--tile-size "$TILE_SIZE")
      [[ "$RADIUS" != "10" ]] && BATCH_ARGS+=(--radius "$RADIUS")
      [[ -n "$PREFIX" ]] && BATCH_ARGS+=(--prefix "$PREFIX")
      bash "$SCRIPT_DIR/post-process.sh" "${BATCH_ARGS[@]}"
    done
    ;;

  srcset)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")/srcset}"
    mkdir -p "$_outdir"
    _base=$(get_prefix)
    _fmt="${FORMAT:-webp}"
    echo "Generating srcset density variants..."
    # Get original dimensions
    _orig_w=$(magick identify -format "%w" "$INPUT")
    # 1x = half original (or custom width), 2x = original, 3x = 1.5x original
    _w1x="${WIDTH:-$(( _orig_w / 2 ))}"
    _w2x=$(( _w1x * 2 ))
    _w3x=$(( _w1x * 3 ))
    magick "$INPUT" -resize "${_w1x}x" -quality "$QUALITY" "$_outdir/${_base}-${_w1x}w.${_fmt}"
    report "$_outdir/${_base}-${_w1x}w.${_fmt}"
    magick "$INPUT" -resize "${_w2x}x" -quality "$QUALITY" "$_outdir/${_base}-${_w2x}w.${_fmt}"
    report "$_outdir/${_base}-${_w2x}w.${_fmt}"
    if [[ "$_w3x" -le "$(( _orig_w + 100 ))" ]]; then
      magick "$INPUT" -resize "${_w3x}x" -quality "$QUALITY" "$_outdir/${_base}-${_w3x}w.${_fmt}"
      report "$_outdir/${_base}-${_w3x}w.${_fmt}"
    fi
    echo "srcset complete: $_outdir/"
    echo "  HTML: srcset=\"${_base}-${_w1x}w.${_fmt} ${_w1x}w, ${_base}-${_w2x}w.${_fmt} ${_w2x}w\""
    ;;

  responsive-hero)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")/responsive-hero}"
    mkdir -p "$_outdir"
    _base=$(get_prefix)
    _fmt="${FORMAT:-webp}"
    echo "Generating responsive hero set with art-direction crops..."
    # Desktop 16:9
    magick "$INPUT" -resize "1920x1080^" -gravity center -extent 1920x1080 -quality "$QUALITY" "$_outdir/${_base}-desktop.${_fmt}"
    report "$_outdir/${_base}-desktop.${_fmt}"
    # Laptop 16:9 smaller
    magick "$INPUT" -resize "1440x810^" -gravity center -extent 1440x810 -quality "$QUALITY" "$_outdir/${_base}-laptop.${_fmt}"
    report "$_outdir/${_base}-laptop.${_fmt}"
    # Tablet 4:3
    magick "$INPUT" -resize "1024x768^" -gravity center -extent 1024x768 -quality "$QUALITY" "$_outdir/${_base}-tablet.${_fmt}"
    report "$_outdir/${_base}-tablet.${_fmt}"
    # Mobile 3:4 (vertical crop, center focal point)
    magick "$INPUT" -resize "768x1024^" -gravity center -extent 768x1024 -quality "$QUALITY" "$_outdir/${_base}-mobile.${_fmt}"
    report "$_outdir/${_base}-mobile.${_fmt}"
    echo "Responsive hero set complete: $_outdir/"
    echo "  Use <picture> with media queries for art direction"
    ;;

  webp-fallback)
    _outdir="${OUTPUT_DIR:-$(dirname "$INPUT")}"
    _base=$(basename "$INPUT" | sed 's/\.[^.]*$//')
    echo "Generating WebP + JPEG fallback pair..."
    magick "$INPUT" -quality "$QUALITY" "$_outdir/${_base}.webp"
    report "$_outdir/${_base}.webp"
    magick "$INPUT" -quality "$QUALITY" -background white -flatten "$_outdir/${_base}.jpg"
    report "$_outdir/${_base}.jpg"
    echo "Use: <picture><source srcset=\"${_base}.webp\" type=\"image/webp\"><img src=\"${_base}.jpg\"></picture>"
    ;;

  dark-variant)
    [[ -z "$OUTPUT" ]] && OUTPUT=$(auto_output "png")
    ensure_dir "$OUTPUT"
    echo "Generating dark mode variant..."
    # Increase brightness of mid-tones, boost saturation by 10%, darken the overall image
    magick "$INPUT" -modulate 85,110,100 -level "5%,90%" -quality "$QUALITY" "$OUTPUT"
    report "$OUTPUT"
    echo "Note: This is a luminance/saturation shift. For best results, regenerate with a dark-mode-specific prompt."
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Available: resize, convert, favicon, og-image, twitter-card, apple-touch,"
    echo "  pwa-icons, hero, thumbnail, transparency, extract-meta, optimize,"
    echo "  blur, grayscale, watermark, sprite, background, batch,"
    echo "  srcset, responsive-hero, webp-fallback, dark-variant"
    exit 1
    ;;
esac
