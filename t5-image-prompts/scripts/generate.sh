#!/usr/bin/env bash
# T5 Image Prompt Generator — Segmind PrunaP API
# Generates images from T5 prompts via Segmind's PrunaP endpoint
#
# Usage:
#   ./generate.sh --prompt "..." --output ./path/to/image.jpg [options]
#
# API Key Resolution (checked in order):
#   1. --api-key flag
#   2. SEGMIND_API_KEY environment variable
#   3. ~/.claude/settings.json → env.SEGMIND_API_KEY
#   4. .env or .env.local in current directory
#
# Options:
#   --prompt        Required. The T5 prompt text
#   --output        Required. Output file path (extension auto-corrected to match format)
#   --aspect-ratio  Aspect ratio: 1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, custom (default: 16:9)
#                   Preset ratios use maximum resolution (1440 on longest edge)
#   --width         Custom width 256-1440 (only with --aspect-ratio custom)
#   --height        Custom height 256-1440 (only with --aspect-ratio custom)
#   --seed          Seed for reproducibility. -1 for random (default: -1)
#   --format        Output format: auto, jpg, png, webp (default: auto = keep API format)
#   --safe          Enable safety checker (default: true)
#   --unsafe        Disable safety checker
#   --api-key       Segmind API key (overrides env)
#   --dry-run       Print the request payload without sending
#   --verbose       Show full API response and debug info
#
# Notes:
#   - PrunaP API typically returns JPEG images
#   - If --output extension doesn't match actual format, it will be auto-corrected
#   - Use --format png to convert to PNG (requires ImageMagick)

set -euo pipefail

# --- Defaults ---
PROMPT=""
OUTPUT=""
ASPECT_RATIO="16:9"
WIDTH=1024
HEIGHT=1024
SEED=-1
DISABLE_SAFETY=false
API_KEY=""
DRY_RUN=false
VERBOSE=false
FORMAT="auto"  # auto, jpg, png, webp

# --- Parse Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)       PROMPT="$2"; shift 2 ;;
    --output)       OUTPUT="$2"; shift 2 ;;
    --aspect-ratio) ASPECT_RATIO="$2"; shift 2 ;;
    --width)        WIDTH="$2"; shift 2 ;;
    --height)       HEIGHT="$2"; shift 2 ;;
    --seed)         SEED="$2"; shift 2 ;;
    --format)       FORMAT="$2"; shift 2 ;;
    --safe)         DISABLE_SAFETY=false; shift ;;
    --unsafe)       DISABLE_SAFETY=true; shift ;;
    --api-key)      API_KEY="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --verbose)      VERBOSE=true; shift ;;
    --help|-h)
      echo "Usage: generate.sh --prompt \"...\" --output ./image.jpg [options]"
      echo ""
      echo "Options:"
      echo "  --prompt TEXT         Required. The T5 prompt text"
      echo "  --output PATH         Required. Output file path (extension auto-corrected)"
      echo "  --aspect-ratio RATIO  1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, custom (default: 16:9)"
      echo "                        Presets use max resolution (1440 on longest edge)"
      echo "  --width N             Custom width 256-1440 (only with --aspect-ratio custom)"
      echo "  --height N            Custom height 256-1440 (only with --aspect-ratio custom)"
      echo "  --seed N              Seed for reproducibility. -1 for random (default: -1)"
      echo "  --format FORMAT       Output format: auto, jpg, png, webp (default: auto)"
      echo "  --safe                Enable safety checker (default)"
      echo "  --unsafe              Disable safety checker"
      echo "  --api-key KEY         Segmind API key (overrides env)"
      echo "  --dry-run             Print request payload without sending"
      echo "  --verbose             Show debug info and full API response"
      echo ""
      echo "Notes:"
      echo "  - PrunaP API typically returns JPEG images"
      echo "  - Extension is auto-corrected to match actual/requested format"
      echo "  - Use --format png/webp to convert (requires ImageMagick)"
      exit 0
      ;;
    *)              echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Validate Required ---
if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt is required"
  exit 1
fi
if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required"
  exit 1
fi

# --- Validate format ---
case "$FORMAT" in
  auto|jpg|jpeg|png|webp) ;;
  *) echo "Error: --format must be auto, jpg, png, or webp (got: $FORMAT)"; exit 1 ;;
esac

# --- Resolve API Key ---
resolve_api_key() {
  # 1. Flag (already set)
  if [[ -n "$API_KEY" ]]; then return; fi

  # 2. Environment variable
  if [[ -n "${SEGMIND_API_KEY:-}" ]]; then
    API_KEY="$SEGMIND_API_KEY"
    return
  fi

  # 3. Claude settings.json
  local claude_settings="$HOME/.claude/settings.json"
  if [[ -f "$claude_settings" ]]; then
    local key
    key=$(jq -r '.env.SEGMIND_API_KEY // empty' "$claude_settings" 2>/dev/null)
    if [[ -n "$key" ]]; then
      API_KEY="$key"
      return
    fi
  fi

  # 4. .env files in current directory
  for envfile in .env .env.local; do
    if [[ -f "$envfile" ]]; then
      local key
      key=$(grep -E "^SEGMIND_API_KEY=" "$envfile" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
      if [[ -n "$key" ]]; then
        API_KEY="$key"
        return
      fi
    fi
  done

  echo "Error: No Segmind API key found."
  echo "Set it via one of:"
  echo "  1. --api-key YOUR_KEY"
  echo "  2. export SEGMIND_API_KEY=YOUR_KEY"
  echo "  3. Add to ~/.claude/settings.json: { \"env\": { \"SEGMIND_API_KEY\": \"YOUR_KEY\" } }"
  echo "  4. Add SEGMIND_API_KEY=YOUR_KEY to .env or .env.local"
  exit 1
}

resolve_api_key

# --- Set dimensions based on aspect ratio ---
# We always send aspect_ratio: "custom" to the API with explicit dimensions.
# This gives us control over resolution (API presets use lower res).
# Max dimension is 1440, and ALL dimensions must be multiples of 16.
# We maximize within those constraints.
set_dimensions() {
  case "$ASPECT_RATIO" in
    # Square: max out at 1440x1440 (both divisible by 16)
    "1:1")   WIDTH=1440; HEIGHT=1440 ;;
    # Landscape 16:9: width maxed, height = 1440 * 9/16 = 810 → round to 816 (multiple of 16)
    "16:9")  WIDTH=1440; HEIGHT=816 ;;
    # Portrait 9:16: height maxed, width = 1440 * 9/16 = 810 → round to 816
    "9:16")  WIDTH=816; HEIGHT=1440 ;;
    # Landscape 4:3: width maxed, height = 1440 * 3/4 = 1080 → round to 1088 (multiple of 16)
    "4:3")   WIDTH=1440; HEIGHT=1088 ;;
    # Portrait 3:4: height maxed, width = 1440 * 3/4 = 1080 → round to 1088
    "3:4")   WIDTH=1088; HEIGHT=1440 ;;
    # Landscape 3:2: width maxed, height = 1440 * 2/3 = 960 (already multiple of 16)
    "3:2")   WIDTH=1440; HEIGHT=960 ;;
    # Portrait 2:3: height maxed, width = 1440 * 2/3 = 960 (already multiple of 16)
    "2:3")   WIDTH=960; HEIGHT=1440 ;;
    "custom")
      # Validate custom dimensions
      if [[ "$WIDTH" -lt 256 || "$WIDTH" -gt 1440 ]]; then
        echo "Error: --width must be between 256 and 1440 (got: $WIDTH)"
        exit 1
      fi
      if [[ "$HEIGHT" -lt 256 || "$HEIGHT" -gt 1440 ]]; then
        echo "Error: --height must be between 256 and 1440 (got: $HEIGHT)"
        exit 1
      fi
      # Round to nearest multiple of 16
      WIDTH=$(( (WIDTH + 8) / 16 * 16 ))
      HEIGHT=$(( (HEIGHT + 8) / 16 * 16 ))
      # Clamp to valid range after rounding
      if [[ "$WIDTH" -gt 1440 ]]; then WIDTH=1440; fi
      if [[ "$HEIGHT" -gt 1440 ]]; then HEIGHT=1440; fi
      if [[ "$WIDTH" -lt 256 ]]; then WIDTH=256; fi
      if [[ "$HEIGHT" -lt 256 ]]; then HEIGHT=256; fi
      ;;
    *)
      echo "Error: Invalid aspect ratio '$ASPECT_RATIO'"
      echo "Allowed: 1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, custom"
      exit 1
      ;;
  esac
}

set_dimensions

# --- Build JSON Payload ---
# Always send aspect_ratio: "custom" with explicit dimensions for max resolution control
PAYLOAD=$(jq -n \
  --arg prompt "$PROMPT" \
  --argjson width "$WIDTH" \
  --argjson height "$HEIGHT" \
  --argjson seed "$SEED" \
  --argjson disable_safety "$DISABLE_SAFETY" \
  '{
    prompt: $prompt,
    aspect_ratio: "custom",
    width: $width,
    height: $height,
    seed: $seed,
    disable_safety_checker: $disable_safety
  }')

if [[ "$DRY_RUN" == true ]]; then
  echo "=== DRY RUN ==="
  echo "Endpoint: https://api.segmind.com/v1/p-image"
  echo "User aspect ratio: $ASPECT_RATIO → dimensions: ${WIDTH}x${HEIGHT}"
  echo "Payload:"
  echo "$PAYLOAD" | jq .
  echo "Output: $OUTPUT"
  echo "Format: $FORMAT"
  exit 0
fi

# --- Ensure output directory exists ---
OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

# --- Make API Call ---
echo "Generating image via Segmind PrunaP..."
echo "  Aspect Ratio: $ASPECT_RATIO (${WIDTH}x${HEIGHT} requested)"
echo "  Seed: $SEED"
echo "  Safety Checker: $(if [[ "$DISABLE_SAFETY" == true ]]; then echo "DISABLED"; else echo "enabled"; fi)"
echo "  Output: $OUTPUT"

RESPONSE_FILE=$(mktemp)
HEADER_FILE=$(mktemp)

HTTP_CODE=$(curl -s -w "%{http_code}" \
  -o "$RESPONSE_FILE" \
  -D "$HEADER_FILE" \
  -X POST "https://api.segmind.com/v1/p-image" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$VERBOSE" == true ]]; then
  echo "=== Response Headers ==="
  cat "$HEADER_FILE"
  echo ""
fi

if [[ "$HTTP_CODE" -ne 200 ]]; then
  echo "Error: API returned HTTP $HTTP_CODE"
  cat "$RESPONSE_FILE"
  rm -f "$RESPONSE_FILE" "$HEADER_FILE"
  exit 1
fi

# --- Detect actual image format ---
CONTENT_TYPE=$(file --mime-type -b "$RESPONSE_FILE")

# Map MIME type to extension
mime_to_ext() {
  case "$1" in
    image/jpeg) echo "jpg" ;;
    image/png)  echo "png" ;;
    image/webp) echo "webp" ;;
    image/gif)  echo "gif" ;;
    *)          echo "bin" ;;
  esac
}

# Get the correct extension for the actual content
ACTUAL_EXT=$(mime_to_ext "$CONTENT_TYPE")

if [[ "$VERBOSE" == true ]]; then
  echo "=== Image Info ==="
  echo "  MIME type: $CONTENT_TYPE"
  echo "  Detected format: $ACTUAL_EXT"
fi

# --- Process response based on content type ---
TEMP_IMAGE="$RESPONSE_FILE"

if [[ "$CONTENT_TYPE" == image/* ]]; then
  # Direct binary image response — good
  :
elif [[ "$CONTENT_TYPE" == application/json ]] || [[ "$CONTENT_TYPE" == text/* ]]; then
  # JSON response — may contain base64 image or URL
  TEMP_IMAGE=$(mktemp)
  
  if jq -e '.image' "$RESPONSE_FILE" &>/dev/null; then
    jq -r '.image' "$RESPONSE_FILE" | base64 -d > "$TEMP_IMAGE"
    echo "  Source: base64 decoded from JSON .image"
  elif jq -e '.url' "$RESPONSE_FILE" &>/dev/null; then
    IMAGE_URL=$(jq -r '.url' "$RESPONSE_FILE")
    DL_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_IMAGE" "$IMAGE_URL")
    if [[ "$DL_CODE" -ne 200 ]]; then
      echo "Error: Failed to download image from URL (HTTP $DL_CODE)"
      echo "URL: $IMAGE_URL"
      rm -f "$TEMP_IMAGE" "$RESPONSE_FILE" "$HEADER_FILE"
      exit 1
    fi
    echo "  Source: downloaded from URL"
  elif jq -e '.data' "$RESPONSE_FILE" &>/dev/null; then
    jq -r '.data' "$RESPONSE_FILE" | base64 -d > "$TEMP_IMAGE"
    echo "  Source: base64 decoded from JSON .data"
  else
    echo "Unexpected JSON response:"
    jq . "$RESPONSE_FILE"
    rm -f "$RESPONSE_FILE" "$HEADER_FILE"
    exit 1
  fi

  if [[ "$VERBOSE" == true ]]; then
    echo "=== Full API Response ==="
    jq . "$RESPONSE_FILE" 2>/dev/null || cat "$RESPONSE_FILE"
  fi
  
  # Re-detect format after extraction
  CONTENT_TYPE=$(file --mime-type -b "$TEMP_IMAGE")
  ACTUAL_EXT=$(mime_to_ext "$CONTENT_TYPE")
  rm -f "$RESPONSE_FILE"
else
  echo "Warning: Unknown response type: $CONTENT_TYPE"
fi

rm -f "$HEADER_FILE"

# --- Check actual dimensions vs requested ---
if command -v magick &>/dev/null; then
  ACTUAL_DIMS=$(magick identify -format "%wx%h" "$TEMP_IMAGE" 2>/dev/null || echo "unknown")
  REQUESTED_DIMS="${WIDTH}x${HEIGHT}"
  
  if [[ "$ACTUAL_DIMS" != "unknown" && "$ACTUAL_DIMS" != "$REQUESTED_DIMS" ]]; then
    echo "  Note: API returned ${ACTUAL_DIMS} (requested ${REQUESTED_DIMS})"
  else
    echo "  Dimensions: $ACTUAL_DIMS"
  fi
fi

# --- Determine final format and extension ---
FINAL_EXT="$ACTUAL_EXT"

if [[ "$FORMAT" != "auto" ]]; then
  # User requested specific format
  case "$FORMAT" in
    jpg|jpeg) FINAL_EXT="jpg" ;;
    png)      FINAL_EXT="png" ;;
    webp)     FINAL_EXT="webp" ;;
  esac
fi

# --- Fix output path extension ---
OUTPUT_BASE="${OUTPUT%.*}"
OUTPUT_GIVEN_EXT="${OUTPUT##*.}"
FINAL_OUTPUT="${OUTPUT_BASE}.${FINAL_EXT}"

# --- Convert if needed ---
if [[ "$FORMAT" != "auto" && "$ACTUAL_EXT" != "$FINAL_EXT" ]]; then
  if command -v magick &>/dev/null; then
    echo "  Converting: $ACTUAL_EXT → $FINAL_EXT"
    magick "$TEMP_IMAGE" "$FINAL_OUTPUT"
    rm -f "$TEMP_IMAGE"
  else
    echo "Warning: ImageMagick not found, cannot convert to $FINAL_EXT"
    echo "  Saving as $ACTUAL_EXT instead"
    FINAL_OUTPUT="${OUTPUT_BASE}.${ACTUAL_EXT}"
    mv "$TEMP_IMAGE" "$FINAL_OUTPUT"
  fi
else
  # No conversion needed, just move/rename
  if [[ "$OUTPUT_GIVEN_EXT" != "$FINAL_EXT" ]]; then
    echo "  Extension corrected: .$OUTPUT_GIVEN_EXT → .$FINAL_EXT"
  fi
  mv "$TEMP_IMAGE" "$FINAL_OUTPUT"
fi

# --- Final output info ---
echo "Image saved to: $FINAL_OUTPUT"

if [[ -f "$FINAL_OUTPUT" ]]; then
  SIZE=$(wc -c < "$FINAL_OUTPUT" | tr -d ' ')
  echo "  File size: $(( SIZE / 1024 )) KB"
  
  # Show final format info
  FINAL_MIME=$(file --mime-type -b "$FINAL_OUTPUT")
  echo "  Format: $FINAL_MIME"
  
  if command -v magick &>/dev/null; then
    magick identify "$FINAL_OUTPUT" 2>/dev/null || true
  fi
fi

echo "Done."
