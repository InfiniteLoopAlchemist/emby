#!/bin/sh

SOURCE_FOLDER="${SOURCE_FOLDER:-"../custom-images"}"
BASE_DESTINATION_FOLDER="${BASE_DESTINATION_FOLDER:-"../config/cache/coverart"}"

# Debugging: Print the source and destination paths
echo "Source folder: $SOURCE_FOLDER"
echo "Base destination folder: $BASE_DESTINATION_FOLDER"

# Check if source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
  echo "Error: Source folder does not exist."
  exit 1
fi

# List the contents of the source folder
echo "Contents of the source folder:"
ls -l "$SOURCE_FOLDER"

# Check if base destination folder exists
if [ ! -d "$BASE_DESTINATION_FOLDER" ]; then
  echo "Error: Base destination folder does not exist."
  exit 1
fi

# Find the correct subdirectory dynamically, excluding the base directory itself
DESTINATION_FOLDER=$(find "$BASE_DESTINATION_FOLDER" -mindepth 1 -maxdepth 1 -type d)

# Debugging: Print the destination folder
echo "Destination folders found:"
echo "$DESTINATION_FOLDER"

# Process each found destination folder
for folder in $DESTINATION_FOLDER; do
  CASE_FOLDER="$folder/case"
  METROCASE_FOLDER="$folder/MetroCase"

  # Create the case folder if it doesn't exist
  if [ ! -d "$CASE_FOLDER" ]; then
    echo "Case folder not found, creating: $CASE_FOLDER"
    mkdir -p "$CASE_FOLDER"
  fi

  # Create the MetroCase folder if it doesn't exist
  if [ ! -d "$METROCASE_FOLDER" ]; then
    echo "MetroCase folder not found, creating: $METROCASE_FOLDER"
    mkdir -p "$METROCASE_FOLDER"
  fi

  # Clear the case folder
  echo "Clearing case folder: $CASE_FOLDER"
  rm -rf "${CASE_FOLDER:?}"/*

  # Copy files to MetroCase folder
  echo "Copying files to MetroCase folder: $METROCASE_FOLDER"
  cp -r "${SOURCE_FOLDER:?}"/* "${METROCASE_FOLDER:?}"

  # List the contents of the MetroCase folder after copying
  echo "Contents of the MetroCase folder after copying:"
  ls -l "$METROCASE_FOLDER"

  # Overwrite all mframe_* images in resources with the black mframe.png
  RESOURCES_DIR="$folder/resources"
  if [ -d "$RESOURCES_DIR" ]; then
    for img in "$RESOURCES_DIR"/mframe_*; do
      if [ -f "$RESOURCES_DIR/mframe.png" ]; then
        echo "Overwriting $img with black mframe.png"
        cp "$RESOURCES_DIR/mframe.png" "$img"
      fi
    done
  fi

  # Overwrite each hashed Series file in SeriesMetroCase with custom Series.png
  SMC_DIR="$folder/SeriesMetroCase"
  if [ -d "$SMC_DIR" ]; then
    for sfile in "$SMC_DIR"/*.png; do
      if [ -f "${SOURCE_FOLDER}/Series.png" ]; then
        echo "Overwriting $sfile with custom Series.png (preserving filename)"
        cp "${SOURCE_FOLDER}/Series.png" "$sfile"
      fi
    done
  fi

done
