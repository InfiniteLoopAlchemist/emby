#!/bin/bash
# Keeps the custom black cover art in place for every Emby instance listed in
# INSTANCES (compose-dir:container-name). Runs every minute from crontab.
#
# All the rules about which folders hold frames live in copy_images.sh. This
# script only asks it (--check) and acts on the answer:
#   exit 10  the plugin drew its own blue frames: apply, then clear Emby's
#            image cache so the blue covers already rendered are redone
#   exit 11  a folder or master is not in place yet (new plugin version):
#            apply, nothing was rendered wrong so the cache is left alone
# Anything else (container stopped, docker error) is skipped until next run.
#
# If a problem is still there right after applying, it is logged once and left
# alone until it changes, so the image cache is never cleared in a loop.

INSTANCES="emby:embyserver hideout-emby:hideout-emby"
BASE=/home/john/Documents/docker-apps
LOG=$BASE/emby/scripts/reapply_images.log

log() { echo "$(date '+%F %T') [$1] $2" >> "$LOG"; }

for pair in $INSTANCES; do
  dir="${pair%%:*}"
  container="${pair##*:}"
  stuck_file="$BASE/emby/scripts/.reapply_stuck.$container"

  found=$(docker exec "$container" /scripts/copy_images.sh --check 2>/dev/null)
  code=$?

  if [ "$code" = 0 ]; then
    rm -f "$stuck_file"
    continue
  fi
  [ "$code" = 10 ] || [ "$code" = 11 ] || continue
  [ -f "$stuck_file" ] && [ "$(cat "$stuck_file")" = "$found" ] && continue

  if [ "$code" = 10 ]; then
    log "$container" "blue defaults detected ($found), re-applying custom images"
    docker exec "$container" /bin/sh -c '/scripts/copy_images.sh >/dev/null 2>&1; rm -rf /config/cache/images/*'
  else
    log "$container" "preparing frames ($found)"
    docker exec "$container" /bin/sh -c '/scripts/copy_images.sh >/dev/null 2>&1'
  fi

  after=$(docker exec "$container" /scripts/copy_images.sh --check 2>/dev/null)
  if [ $? = 0 ]; then
    rm -f "$stuck_file"
    log "$container" "re-applied OK"
  else
    echo "$after" > "$stuck_file"
    log "$container" "re-apply FAILED, still: $after (not retrying until this changes)"
  fi
done
