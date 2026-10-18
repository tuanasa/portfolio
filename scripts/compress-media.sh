#!/usr/bin/env bash
# Compress every photo/video in the portfolio for the web.
#
# Usage:  npm run compress            (or: bash scripts/compress-media.sh)
#         npm run compress -- --dry-run   show what would happen, change nothing
#
# For each media file that isn't web-sized yet:
#   1. the original is moved to ../portfolio-originals/<same path>  (outside the repo:
#      untracked, and never uploaded by the gh-pages deploy)
#   2. a compressed copy is written in its place (photos -> jpg; images with a
#      transparent background stay png so the transparency is kept)
#   3. if the extension changed (e.g. .png -> .jpg), src references in *.html are updated
#
# Safe to run again any time: files that are already small, or whose original is
# already in portfolio-originals, are skipped.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIG="${ORIGINALS_DIR:-$(dirname "$ROOT")/portfolio-originals}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# photos: longest side in px, jpeg quality; jpgs already under this size are left alone
IMG_MAX=2400
IMG_QUALITY=82
IMG_OK_BYTES=$((2 * 1024 * 1024))
# files that must never be touched, relative to the project root
KEEP=()
# smaller max size for images that are only ever shown small ("path:longest side px")
IMG_MAX_FOR=(
  "tuana.png:1200"   # portrait, kept in the repo but no longer on the about page
)
# videos: target width, crf, skip h264 mp4s already under this bitrate
VID_WIDTH=1280
VID_CRF=28
VID_OK_BITRATE=4000000

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)"; exit 1; }
command -v sips >/dev/null || { echo "sips not found (macOS only)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

done_count=0; skip_count=0; saved=0

size_of() { stat -f %z "$1"; }
human() { awk -v b="$1" 'BEGIN { printf (b >= 1048576 ? "%.1f MB" : "%.0f KB"), (b >= 1048576 ? b/1048576 : b/1024) }'; }

# true if the image has at least one (partly) transparent pixel
has_transparency() {
  local min
  min="$(ffmpeg -nostdin -v error -i "$1" -vf "alphaextract,signalstats,metadata=print:key=lavfi.signalstats.YMIN:file=-" -f null - 2>/dev/null \
    | awk -F= '/YMIN/ {print $2; exit}')"
  [ -n "$min" ] && [ "$min" -lt 255 ]
}

# a path as it may appear in html: plain, or url-encoded (space -> %20, & -> %26)
encoded() { printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/&/%26/g'; }

update_refs() {
  local old="$1" new="$2" f
  for f in "$ROOT"/*.html; do
    OLD="$old" NEW="$new" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
    OLD="$(encoded "$old")" NEW="$(encoded "$new")" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
    OLD="${old//&/&amp;}" NEW="${new//&/&amp;}" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
  done
}

process() {
  local rel="$1" src="$ROOT/$1"
  local ext stem lower out tmp_out kind
  ext="${rel##*.}"; stem="${rel%.*}"
  lower="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  local k max="$IMG_MAX"
  for k in ${KEEP[@]+"${KEEP[@]}"}; do [ "$rel" = "$k" ] && { skip_count=$((skip_count + 1)); return; }; done
  for k in "${IMG_MAX_FOR[@]}"; do [ "$rel" = "${k%:*}" ] && max="${k##*:}"; done

  # already handled before? (original with the same name, any extension)
  if ls "$ORIG/$stem".* >/dev/null 2>&1; then
    skip_count=$((skip_count + 1)); return
  fi

  case "$lower" in
    jpg|jpeg|png|tif|tiff|heic|webp)
      kind=image
      local w h long
      w="$(sips -g pixelWidth "$src" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
      h="$(sips -g pixelHeight "$src" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
      [ -z "$w" ] && { echo "  ? can't read $rel, skipped"; skip_count=$((skip_count + 1)); return; }
      long=$(( w > h ? w : h ))
      if [ "$lower" = jpg ] || [ "$lower" = jpeg ]; then
        [ "$(size_of "$src")" -le "$IMG_OK_BYTES" ] && { skip_count=$((skip_count + 1)); return; }
        out="$rel"
      elif has_transparency "$src"; then
        # transparent background: stay png so the transparency survives
        kind=png
        [ "$(size_of "$src")" -le "$IMG_OK_BYTES" ] && [ "$long" -le "$max" ] && { skip_count=$((skip_count + 1)); return; }
        if [ "$lower" = png ]; then out="$rel"; else out="$stem.png"; fi
      else
        out="$stem.jpg"
      fi
      ;;
    mp4|mov|m4v)
      kind=video
      local codec rate
      codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$src" || true)"
      rate="$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$src" || echo 0)"
      [ "$rate" = "N/A" ] && rate=0
      if [ "$lower" = mp4 ] && [ "$codec" = h264 ] && [ "$rate" -gt 0 ] && [ "$rate" -le "$VID_OK_BITRATE" ]; then
        skip_count=$((skip_count + 1)); return
      fi
      out="$stem.mp4"
      ;;
    *) return ;;
  esac

  if [ "$out" != "$rel" ] && [ -e "$ROOT/$out" ]; then
    echo "  ! $rel -> $out: $out already exists, skipped"; skip_count=$((skip_count + 1)); return
  fi

  local before renamed=""
  before="$(size_of "$src")"
  [ "$out" != "$rel" ] && renamed="  (becomes $out)"
  if [ "$DRY" = 1 ]; then
    echo "  would compress $rel ($(human "$before"))$renamed"
    done_count=$((done_count + 1)); return
  fi

  tmp_out="$TMP/out.${out##*.}"
  rm -f "$tmp_out"
  if [ "$kind" = png ]; then
    if [ "$long" -gt "$max" ]; then
      sips -s format png -Z "$max" "$src" --out "$tmp_out" >/dev/null
    else
      sips -s format png "$src" --out "$tmp_out" >/dev/null
    fi
    # optional: much smaller transparent pngs if pngquant is installed (brew install pngquant)
    if command -v pngquant >/dev/null; then
      pngquant --force --skip-if-larger --quality 70-90 --output "$tmp_out" -- "$tmp_out" || true
    fi
  elif [ "$kind" = image ]; then
    if [ "$long" -gt "$max" ]; then
      sips -s format jpeg -s formatOptions "$IMG_QUALITY" -Z "$max" "$src" --out "$tmp_out" >/dev/null
    else
      sips -s format jpeg -s formatOptions "$IMG_QUALITY" "$src" --out "$tmp_out" >/dev/null
    fi
  else
    ffmpeg -nostdin -loglevel error -y -i "$src" \
      -vf "scale='min($VID_WIDTH,iw)':-2" -c:v libx264 -crf "$VID_CRF" -preset slow \
      -an -movflags +faststart -pix_fmt yuv420p "$tmp_out"
  fi

  local after; after="$(size_of "$tmp_out")"
  if [ "$out" = "$rel" ] && [ "$after" -ge "$before" ]; then
    echo "  = $rel is already as small as it gets, kept"
    skip_count=$((skip_count + 1)); return
  fi

  mkdir -p "$(dirname "$ORIG/$rel")"
  mv -n "$src" "$ORIG/$rel"
  mv "$tmp_out" "$ROOT/$out"
  if [ "$out" != "$rel" ]; then update_refs "$rel" "$out"; fi

  echo "  ✓ $rel  $(human "$before") -> $(human "$after")$renamed"
  saved=$((saved + before - after))
  done_count=$((done_count + 1))
}

echo "Originals folder: $ORIG"
[ "$DRY" = 1 ] && echo "(dry run, nothing will change)"

while IFS= read -r -d '' file; do
  process "${file#"$ROOT"/}"
done < <(find "$ROOT" \( -name .git -o -name node_modules -o -name scripts -o -name .claude -o -name favicon \) -prune -o \
           -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \
           -o -iname '*.heic' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \) -print0 | sort -z)

echo
if [ "$DRY" = 1 ]; then
  echo "$done_count file(s) would be compressed, $skip_count already fine."
else
  echo "$done_count file(s) compressed, $skip_count already fine. Saved $(human "$saved")."
fi
