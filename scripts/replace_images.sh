#!/bin/sh

# Define the source and destination directories
CUSTOM_IMAGES_DIR="/custom-images/emby"

# List of custom image files and their destinations in the container
FILES_TO_COPY="icon-128x128.png:/system/dashboard-ui/images/icon-128x128.png
icon-152x152.png:/system/dashboard-ui/images/icon-152x152.png
icon-72x72.png:/system/dashboard-ui/images/icon-72x72.png
icon-96x96.png:/system/dashboard-ui/images/icon-96x96.png
icon-384x384.png:/system/dashboard-ui/images/icon-384x384.png
icon-192x192.png:/system/dashboard-ui/images/icon-192x192.png
splash.png:/system/dashboard-ui/images/splash.png
icon-512x512.png:/system/dashboard-ui/images/icon-512x512.png
icon-144x144.png:/system/dashboard-ui/images/icon-144x144.png
logowhite.png:/system/dashboard-ui/modules/themes/logowhite.png
logodark.png:/system/dashboard-ui/modules/themes/logodark.png
logowhite.png:/system/dashboard-ui/modules/logoscreensaver/logowhite.png
favicon.ico:/system/dashboard-ui/favicon.ico"

# Copy each custom image to the corresponding location in the container
echo "$FILES_TO_COPY" | while IFS=: read -r SRC DEST; do
  SRC_FILE="${CUSTOM_IMAGES_DIR}/${SRC}"
  DEST_PATH="${DEST}"

  # Use cp to copy the file
  if [ -f "$SRC_FILE" ]; then
    cp "$SRC_FILE" "$DEST_PATH"
    echo "Copied $SRC_FILE to $DEST_PATH"
  else
    echo "File $SRC_FILE does not exist."
  fi
done

echo "Custom images have been replaced."