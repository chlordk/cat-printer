#!/bin/bash
# by Hans Schou 2026
set -e

MAC=${1}
TXT=${2:-Hêllø, wörld!}

if [[ -z $MAC ]]
then
  cat <<EOF
  Error: No MAC address specified on command line.
  Syntax: $0 <MAC> [Text]
EOF
  exit 1
fi

# Bind bluetooth MAC address to a character device on port 2
if [[ ! -c /dev/rfcomm0 ]]
then
  echo Bind bluetooth to a character device:
  sudo rfcomm bind 0 "$MAC" 2
fi

# Convert ASCII hex to binary in a safe way.
hex2bin() {
  echo "$1" | xxd -r -p
}

# ESC/POS Instructions
INIT="1b40"
END="0a0a0a"

# Raster command: GS v 0 0 (1d 76 30 00)
# Width: 384 px = 48 bytes -> 0x0030 (30 00)
# Height: 100 px -> 0x0064 (64 00)
RASTER_INIT="1d76300030006400"

(
  # 1. Reset printer
  hex2bin "$INIT"
  #sleep 0.1

  # 2. Send raster header
  hex2bin "$RASTER_INIT"

  # 3. Send only raw binary pixel data (cut the 2 header-lines from PBM)
  convert -size 384x100 -pointsize 32 canvas:white \
    -font DejaVu-Sans -fill black -gravity center \
    -annotate 0 "$TXT" -monochrome PBM:- | sed -e '1,2d'

  # 4. Send line feeds
  hex2bin "$END"
) > /dev/rfcomm0
