#!/bin/bash
# Re-applies the custom black cover art whenever the Cover Art plugin has
# regenerated its cache with blue defaults, for every Emby instance listed
# in INSTANCES (compose-dir:container-name). Safe to run any time: it only
# acts (docker exec + image-cache clear) when a checksum mismatch is found.
# Installed in crontab to run hourly.

INSTANCES="emby:embyserver hideout-emby:hideout-emby"
BASE=/home/john/Documents/docker-apps
LOG=$BASE/emby/scripts/reapply_images.log

for pair in $INSTANCES; do
  dir="${pair%%:*}"
  container="${pair##*:}"
  SRC="$BASE/$dir/custom-images"
  COVERART="$BASE/$dir/config/cache/coverart"
  [ -d "$COVERART" ] || continue

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

  [ -n "$mismatch" ] || continue

  echo "$(date '+%F %T') [$container] blue defaults detected ($mismatch), re-applying custom images" >> "$LOG"
  if docker exec "$container" /bin/sh -c '/scripts/copy_images.sh >/dev/null 2>&1; rm -rf /config/cache/images/*'; then
    echo "$(date '+%F %T') [$container] re-applied OK" >> "$LOG"
  else
    echo "$(date '+%F %T') [$container] re-apply FAILED (is it running?)" >> "$LOG"
  fi
done
