#!/bin/sh
# Puts the custom black cover frames into every folder the Emby Cover Art
# plugin reads its frames from.
#
#   copy_images.sh          apply the black frames
#   copy_images.sh --check  change nothing, report the first problem:
#                             exit 0   everything is black
#                             exit 10  a frame has the plugin's own (blue) art,
#                                      or a font file is the plugin's own font
#                             exit 11  a folder or master is not in place yet
#
# The plugin keeps one cache folder per plugin version and renames its frame
# folders between versions (4.1.30 moved from MetroCase to
# skia-frames-v2-MetroCase, which is how the blue frames came back in
# October 2026). So nothing here names a folder outright, it goes by the end
# of the folder name:
#   *SeriesMetroCase/   every png in it is the Series frame
#   *MetroCase/         one png per frame type (BD.png, Series.png, ...)
#   *case/              copies the plugin derives from the above, cleared
#   resources/mframe_*  tinted variants of resources/mframe.png
#   fonts/*.ttf         the font the plugin writes "Season 18" with, replaced
#                       by custom-images/cover-font.ttf (Fatbasterd Pixel with
#                       small letters drawn as capitals)
#
# It also prepares the cache folder of the installed plugin version before the
# plugin has made it, so a plugin update never gets to draw a blue frame.
#
# reapply_images_cron.sh runs the --check form every minute and applies on a
# problem, so the rules live here only.

SOURCE_FOLDER="${SOURCE_FOLDER:-"../custom-images"}"
BASE_DESTINATION_FOLDER="${BASE_DESTINATION_FOLDER:-"../config/cache/coverart"}"
PLUGIN_DLL="${PLUGIN_DLL:-"../config/plugins/CoverArt.dll"}"
COVER_FONT="$SOURCE_FOLDER/cover-font.ttf"

CHECK=0
[ "$1" = "--check" ] && CHECK=1

if [ ! -d "$SOURCE_FOLDER" ]; then
  echo "Error: Source folder does not exist: $SOURCE_FOLDER"
  exit 1
fi
if [ ! -f "$SOURCE_FOLDER/Series.png" ]; then
  echo "Error: no Series.png in $SOURCE_FOLDER"
  exit 1
fi
if [ ! -d "$BASE_DESTINATION_FOLDER" ]; then
  echo "Error: Base destination folder does not exist: $BASE_DESTINATION_FOLDER"
  exit 1
fi

OWNER=$(stat -c '%u:%g' "$BASE_DESTINATION_FOLDER" 2>/dev/null)
WRONG=""
MISSING=""

note_wrong() { [ -n "$WRONG" ] || WRONG="$1"; }
note_missing() { [ -n "$MISSING" ] || MISSING="$1"; }

# Version folders, oldest first.
version_dirs() {
  for v in "$BASE_DESTINATION_FOLDER"/*/; do
    [ -d "$v" ] && basename "$v"
  done | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n
}

# The version of the plugin file on disk. After an update this is the NEXT
# version Emby will load, its cache folder does not exist yet.
installed_version() {
  [ -f "$PLUGIN_DLL" ] || return 0
  tr -d '\000' < "$PLUGIN_DLL" 2>/dev/null \
    | grep -a -o 'Assembly Version[0-9][0-9.]*' \
    | head -n1 | sed 's/Assembly Version//'
}

# Newest OTHER version folder that has frame folders, used as the layout for
# the installed version ($1). The installed version's own folder is left out
# because the plugin fills it in bit by bit, so it can be incomplete.
template_dir() {
  for v in $(version_dirs | sed '1!G;h;$!d'); do
    [ "$v" = "$1" ] && continue
    for d in "$BASE_DESTINATION_FOLDER/$v"/*MetroCase; do
      if [ -d "$d" ]; then
        echo "$BASE_DESTINATION_FOLDER/$v"
        return 0
      fi
    done
  done
}

make_dir() {
  mkdir -p "$1" || return 1
  [ -n "$OWNER" ] && chown "$OWNER" "$1" 2>/dev/null
  return 0
}

# Give the installed version's folder the same frame folders as the template.
seed_installed_version() {
  ver=$(installed_version)
  [ -n "$ver" ] || return 0
  tpl=$(template_dir "$ver")
  [ -n "$tpl" ] || return 0
  target="$BASE_DESTINATION_FOLDER/$ver"

  for d in "$tpl"/*MetroCase; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ ! -d "$target/$name" ]; then
      if [ "$CHECK" = 1 ]; then
        note_missing "$target/$name"
        continue
      fi
      echo "Preparing $target/$name"
      [ -d "$target" ] || make_dir "$target" || continue
      make_dir "$target/$name" || continue
    fi
    case "$name" in
      *SeriesMetroCase)
        # Same file names as the template, the plugin looks them up by name.
        for f in "$d"/*.png; do
          [ -f "$f" ] || continue
          t="$target/$name/$(basename "$f")"
          [ -f "$t" ] && continue
          if [ "$CHECK" = 1 ]; then
            note_missing "$t"
          else
            cp "$SOURCE_FOLDER/Series.png" "$t"
          fi
        done
        ;;
    esac
  done

  # Same font file names as the template, each one the pixel font.
  [ -f "$COVER_FONT" ] || return 0
  for f in "$tpl"/fonts/*.ttf; do
    [ -f "$f" ] || continue
    t="$target/fonts/$(basename "$f")"
    [ -f "$t" ] && continue
    if [ "$CHECK" = 1 ]; then
      note_missing "$t"
      continue
    fi
    [ -d "$target" ] || make_dir "$target" || continue
    [ -d "$target/fonts" ] || make_dir "$target/fonts" || continue
    cp "$COVER_FONT" "$t"
  done
}

apply_fonts_dir() {
  [ -f "$COVER_FONT" ] || return 0
  for f in "$1"/*.ttf; do
    [ -f "$f" ] || continue
    cmp -s "$COVER_FONT" "$f" && continue
    if [ "$CHECK" = 1 ]; then
      note_wrong "$f"
    else
      cp "$COVER_FONT" "$f"
    fi
  done
}

apply_series_dir() {
  for f in "$1"/*.png; do
    [ -f "$f" ] || continue
    cmp -s "$SOURCE_FOLDER/Series.png" "$f" && continue
    if [ "$CHECK" = 1 ]; then
      note_wrong "$f"
    else
      cp "$SOURCE_FOLDER/Series.png" "$f"
    fi
  done
}

apply_frame_dir() {
  for img in "$SOURCE_FOLDER"/*.png; do
    [ -f "$img" ] || continue
    t="$1/$(basename "$img")"
    cmp -s "$img" "$t" && continue
    if [ "$CHECK" = 1 ]; then
      if [ -f "$t" ]; then note_wrong "$t"; else note_missing "$t"; fi
    else
      cp "$img" "$t"
    fi
  done
}

apply_resources_dir() {
  [ -f "$1/mframe.png" ] || return 0
  for img in "$1"/mframe_*; do
    [ -f "$img" ] || continue
    cmp -s "$1/mframe.png" "$img" && continue
    if [ "$CHECK" = 1 ]; then
      note_wrong "$img"
    else
      cp "$1/mframe.png" "$img"
    fi
  done
}

seed_installed_version

for v in $(version_dirs); do
  folder="$BASE_DESTINATION_FOLDER/$v"
  for d in "$folder"/*; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
      *SeriesMetroCase) apply_series_dir "$d" ;;
      *MetroCase) apply_frame_dir "$d" ;;
      *case) [ "$CHECK" = 1 ] || rm -rf "${d:?}"/* ;;
      resources) apply_resources_dir "$d" ;;
      fonts) apply_fonts_dir "$d" ;;
    esac
  done
done

if [ "$CHECK" = 1 ]; then
  if [ -n "$WRONG" ]; then
    echo "wrong frame: $WRONG"
    exit 10
  fi
  if [ -n "$MISSING" ]; then
    echo "not in place: $MISSING"
    exit 11
  fi
  echo "ok"
  exit 0
fi

echo "Black cover frames applied in: $(version_dirs | tr '\n' ' ')"
exit 0
