#!/bin/sh
# Makes every browser and Emby app fetch the covers again.
#
# Emby tells clients to keep a cover for a year and only hands out a new
# address for it when the Cover Art plugin's settings change. Swapping a frame
# image or the cover font changes no setting, so clients keep showing the old
# cover from their own cache. This writes a new "CoverRev" entry into the
# plugin's type map (the plugin only ever looks entries up by media type, so
# the entry does nothing else), which changes the address of every cover.
#
#   refresh_covers.sh <compose-dir> <container>
#   refresh_covers.sh hideout-emby hideout-emby
#   refresh_covers.sh emby embyserver
#
# Emby reads the plugin settings at start, so the container is stopped and
# started (about 20 seconds). It is started again even if the edit fails.

BASE=/home/john/Documents/docker-apps
dir="$1"
container="$2"
if [ -z "$dir" ] || [ -z "$container" ]; then
  echo "usage: refresh_covers.sh <compose-dir> <container>"
  exit 1
fi
xml="$BASE/$dir/config/plugins/configurations/CoverArt.xml"
if [ ! -f "$xml" ]; then
  echo "Error: no plugin settings at $xml"
  exit 1
fi
rev=$(date +%Y%m%d%H%M%S)

docker stop "$container" >/dev/null || exit 1

python3 - "$xml" "$rev" <<'EOF'
import re, sys
import xml.etree.ElementTree as ET

path, rev = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
original = text

item = (
    "            <item>\n"
    "              <key>\n"
    "                <string>CoverRev</string>\n"
    "              </key>\n"
    "              <value>\n"
    "                <string>%s</string>\n"
    "              </value>\n"
    "            </item>\n" % rev
)

# Drop the entry from an earlier run, then add the new one to every profile.
text = re.sub(
    r"[ \t]*<item>\s*<key>\s*<string>CoverRev</string>\s*</key>\s*<value>\s*"
    r"<string>[^<]*</string>\s*</value>\s*</item>\n?",
    "",
    text,
)
text = re.sub(r"([ \t]*)<TypeMap\s*/>", r"\1<TypeMap>\n\1</TypeMap>", text)
new, count = re.subn(r"([ \t]*)</TypeMap>", lambda m: item + m.group(0), text)
if count == 0:
    sys.exit("no TypeMap in %s, nothing changed" % path)

ET.fromstring(new.encode("utf-8"))  # refuse to write broken XML
open(path + ".bak", "w", encoding="utf-8").write(original)
open(path, "w", encoding="utf-8").write(new)
print("CoverRev %s written to %d profile(s)" % (rev, count))
EOF
status=$?

docker start "$container" >/dev/null || exit 1
exit $status
