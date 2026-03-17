#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./convert_appstore_screenshot.sh <input> <output> [options]

Options:
  --preset <name>         Target preset (default: iphone67-portrait)
  --width <px>            Custom width (overrides preset)
  --height <px>           Custom height (overrides preset)
  --mode <fit|fill>       fit = letterbox, fill = center-crop (default: fill)
  --bg <hex>              Padding color for fit mode (default: FFFFFF)

Presets:
  iphone67-portrait       1290x2796
  iphone67-landscape      2796x1290
  iphone65-portrait       1242x2688
  iphone65-landscape      2688x1242
  ipad129-portrait        2048x2732
  ipad129-landscape       2732x2048

Examples:
  ./convert_appstore_screenshot.sh in.png out.png --preset iphone67-portrait
  ./convert_appstore_screenshot.sh in.png out.png --width 1290 --height 2796 --mode fit --bg 000000
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 2 ]]; then
  usage
  exit 0
fi

input="$1"
output="$2"
shift 2

if [[ ! -f "$input" ]]; then
  echo "Input file not found: $input" >&2
  exit 1
fi

preset="iphone67-portrait"
mode="fill"
bg="FFFFFF"
custom_w=""
custom_h=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      preset="$2"
      shift 2
      ;;
    --width)
      custom_w="$2"
      shift 2
      ;;
    --height)
      custom_h="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --bg)
      bg="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$preset" in
  iphone67-portrait) tw=1290; th=2796 ;;
  iphone67-landscape) tw=2796; th=1290 ;;
  iphone65-portrait) tw=1242; th=2688 ;;
  iphone65-landscape) tw=2688; th=1242 ;;
  ipad129-portrait) tw=2048; th=2732 ;;
  ipad129-landscape) tw=2732; th=2048 ;;
  *)
    echo "Unknown preset: $preset" >&2
    exit 1
    ;;
esac

if [[ -n "$custom_w" ]]; then tw="$custom_w"; fi
if [[ -n "$custom_h" ]]; then th="$custom_h"; fi

if [[ ! "$tw" =~ ^[0-9]+$ || ! "$th" =~ ^[0-9]+$ ]]; then
  echo "Width and height must be integers." >&2
  exit 1
fi

if [[ "$mode" != "fit" && "$mode" != "fill" ]]; then
  echo "Mode must be 'fit' or 'fill'." >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"

src_w=$(sips -g pixelWidth "$input" | awk '/pixelWidth:/ {print $2}')
src_h=$(sips -g pixelHeight "$input" | awk '/pixelHeight:/ {print $2}')

if [[ -z "$src_w" || -z "$src_h" ]]; then
  echo "Could not read input dimensions." >&2
  exit 1
fi

tmpfile=$(mktemp "/tmp/appstore_convert.XXXXXX.png")
trap 'rm -f "$tmpfile"' EXIT
cp "$input" "$tmpfile"

if [[ "$mode" == "fill" ]]; then
  # Fill target and center-crop
  src_ratio=$(awk -v w="$src_w" -v h="$src_h" 'BEGIN { printf "%.10f", w / h }')
  tgt_ratio=$(awk -v w="$tw" -v h="$th" 'BEGIN { printf "%.10f", w / h }')

  if awk -v s="$src_ratio" -v t="$tgt_ratio" 'BEGIN { exit !(s > t) }'; then
    scaled_w=$(awk -v sw="$src_w" -v sh="$src_h" -v th="$th" 'BEGIN { printf "%d", (sw * th / sh) + 0.5 }')
    sips --resampleHeightWidth "$th" "$scaled_w" "$tmpfile" >/dev/null
  else
    scaled_h=$(awk -v sw="$src_w" -v sh="$src_h" -v tw="$tw" 'BEGIN { printf "%d", (sh * tw / sw) + 0.5 }')
    sips --resampleHeightWidth "$scaled_h" "$tw" "$tmpfile" >/dev/null
  fi

  sips --cropToHeightWidth "$th" "$tw" "$tmpfile" >/dev/null
else
  # Fit inside target and pad
  src_ratio=$(awk -v w="$src_w" -v h="$src_h" 'BEGIN { printf "%.10f", w / h }')
  tgt_ratio=$(awk -v w="$tw" -v h="$th" 'BEGIN { printf "%.10f", w / h }')

  if awk -v s="$src_ratio" -v t="$tgt_ratio" 'BEGIN { exit !(s > t) }'; then
    scaled_h=$(awk -v sw="$src_w" -v sh="$src_h" -v tw="$tw" 'BEGIN { printf "%d", (sh * tw / sw) + 0.5 }')
    sips --resampleHeightWidth "$scaled_h" "$tw" "$tmpfile" >/dev/null
  else
    scaled_w=$(awk -v sw="$src_w" -v sh="$src_h" -v th="$th" 'BEGIN { printf "%d", (sw * th / sh) + 0.5 }')
    sips --resampleHeightWidth "$th" "$scaled_w" "$tmpfile" >/dev/null
  fi

  sips --padColor "$bg" --padToHeightWidth "$th" "$tw" "$tmpfile" >/dev/null
fi

ext="${output##*.}"
ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
  sips -s format jpeg -s formatOptions best "$tmpfile" --out "$output" >/dev/null
else
  cp "$tmpfile" "$output"
fi

out_w=$(sips -g pixelWidth "$output" | awk '/pixelWidth:/ {print $2}')
out_h=$(sips -g pixelHeight "$output" | awk '/pixelHeight:/ {print $2}')

echo "✅ Converted: $input"
echo "   Output:    $output"
echo "   Size:      ${out_w}x${out_h}"
echo "   Mode:      $mode"
