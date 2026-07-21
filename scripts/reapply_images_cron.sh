#!/bin/bash
# Re-applies the custom black cover art whenever the Cover Art plugin has
# regenerated its cache with blue defaults. Safe to run any time: it only
# acts (docker exec + image-cache clear) when a checksum mismatch is found.
# Installed in crontab to run hourly.

EMBY_DIR=/home/john/Documents/docker-apps/emby
SRC="$EMBY_DIR/custom-images"
COVERART="$EMBY_DIR/config/cache/coverart"
LOG="$EMBY_DIR/scripts/reapply_images.log"

[ -d "$COVERART" ] || exit 0

series_md5=$(md5sum "$SRC/Series.png" | cut -d' ' -f1)
mismatch=""

for vdir in "$COVERART"/*/; do
  res="${vdir}resources"
  if [ -f "$res/mframe.png" ]; then
    frame_md5=$(md5sum "$res/mframe.png" | cut -d' ' -f1)
    for f in "$res"/mframe_*; do
      [ -f "$f" ] || continue
      [ "$(md5sum "$f" | cut -d' ' -f1)" = "$frame_md5" ] || mismatch="$f"
    done
  fi
  for f in "${vdir}SeriesMetroCase"/*.png; do
    [ -f "$f" ] || continue
    [ "$(md5sum "$f" | cut -d' ' -f1)" = "$series_md5" ] || mismatch="$f"
  done
  for img in "$SRC"/*.png; do
    t="${vdir}MetroCase/$(basename "$img")"
    [ -f "$t" ] || continue
    [ "$(md5sum "$t" | cut -d' ' -f1)" = "$(md5sum "$img" | cut -d' ' -f1)" ] || mismatch="$t"
  done
done

[ -n "$mismatch" ] || exit 0

echo "$(date '+%F %T') blue defaults detected ($mismatch), re-applying custom images" >> "$LOG"
if docker exec embyserver /bin/sh -c '/scripts/copy_images.sh >/dev/null 2>&1; rm -rf /config/cache/images/*'; then
  echo "$(date '+%F %T') re-applied OK" >> "$LOG"
else
  echo "$(date '+%F %T') re-apply FAILED (is embyserver running?)" >> "$LOG"
fi
