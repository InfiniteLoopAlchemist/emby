#!/bin/sh

PLUGIN_CACHE_DIR="/cache/coverart"
COPY_SCRIPT="/scripts/copy_images.sh"

# Monitor the plugin cache directory for changes
inotifywait -m -e create -e moved_to --format '%w%f' "$PLUGIN_CACHE_DIR" | while read -r NEW_DIR
do
  echo "New directory detected: $NEW_DIR"
  /bin/sh "$COPY_SCRIPT"
done