#! /bin/bash
# by Hans Schou 2026
set -e

# On Ubuntu/Debian/Mint the following packages is needed:
# * bluez
#
# The printers MAC address can be found with:
# bluetoothctl:
#   scan on
# The printer show up like this:
#   [CHG] Device 00:11:22:AB:CD:EF RSSI: 0xffffffd0 (-48)
#   [CHG] Device 00:11:22:AB:CD:EF ManufacturerData.Key: 0x0000 (0)
# bluetoothctl:
#   trust 00:11:22:AB:CD:EF
#   pair 00:11:22:AB:CD:EF
#   exit
#
# Now we can bind the bluetooth channel as a serial device:
#   sudo rfcomm bind 0 00:11:22:AB:CD:EF 2
# Check the new device:
#   ls -l /dev/rfcomm0
# Make sure your user is member of 'dialout'
#   sudo usermod -a -G dialout $USER

# Quick status:
#   cat /dev/rfcomm0 & CAT=$!
#   printf '\x1e\x47\x03' > /dev/rfcomm0
#   kill $CAT

# Description of all ESC/POS printer commands:
# https://escpos.readthedocs.io/en/latest/commands.html

MAC=${1}
if [[ -z $MAC ]]
then
	cat <<EOF
  Error: No MAC address specified on command line.

  Syntax: $0 <MAC>

  Example: $0 00:11:22:AB:Cd:ef

  When the printer is turned on,
  double click the button and the printer
  will print a page with the MAC address.
  The format looks like: 00:11:22:AB:Cd:ef
EOF
	exit 1
fi

# If device rfcomm0 not exist, create it
if [[ ! -c /dev/rfcomm0 ]]
then
	sudo rfcomm bind 0 $MAC 2
fi

# Define the components
INIT="1b40"
END="0a0a0a0a"

# Init raster image hex '1d7630' and mode hex '00'.
# A dashed bar: 384 pixels wide (48 bytes -> hex '30 00') and 20 pixels tall (hex '14 00')
# Followed by 960 bytes of solid black data ('c3' repeated 960 times)
BAR_CMD="1d76300030001400$(printf 'c3%.0s' {1..960})"

for hex in "$INIT" "$BAR_CMD" "$END" ; do
    echo -en "$(echo "$hex" | sed 's/\(..\)/\\x\1/g')"
    sleep 0.05
done > /dev/rfcomm0
