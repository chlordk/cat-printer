# Developer

Here are some information relevant to developers.

## Serial port console

The Bluetooth can be assigned like a serial port and then
be used with serial port tools like `minicom` and `CuteCom`.
As `minicom` is hard entering hex numbers `CuteCom` is used here.

To bind the bluetooth device MAC as a serial port on channel run the command:

```
sudo rfcomm bind 0 00:11:22:AB:CD:EF 2
```

and the device will be created:

```
crw-rw---- 1 root dialout 216, 0 Aug  1 23:01 /dev/rfcomm0
```

Then all users in group `dialout` can write to it.
If you are not member of the group run:

```
sudo usermod -a -G dialout $USER
```

Start `CuteCom` and open the device `/dev/rfcomm0` and
enter the `request status` in hex `1e 47 03`:

![CuteCom](../CuteCom.png)

and the status will shown `HV=H1.0,SV=V1.01,VOLT=7720mv,DPI=384,<break>`.

If you send the hex command `0a` the paper will adance one line.
Other command are `serial number` `1d 67 39`, and `product info` `1d 67 69`
which can be seen used in [cat-printer](../cat-printer).

## bash_test.sh

[bash_test.sh](bash_test.sh)
is a simple BASH script which print a demo to the printer.

This test requires `bluez` installed:

```
sudo apt install bluez
```

From the `bluez` package `rfcomm` will be used to bind the
bluetooth MAC address to character device `/dev/rfcomm0`.
It will be similar to a serial port device with direct access
to the MCU inside the printer.

```
bash_test.sh 00:11:22:AB:CD:EF
```

The image will look like the image below:

![dash-bar.png](dash-bar.png)

The printout will take about 4 seconds.
Depended in which order you `rfcomm bind` the device and
connect it you can get `Permission denied`.
To make it easy pre-fix `sudo` to the command.


## imagemagick_test.sh

[imagemagick_test.sh](imagemagick_test.sh)
takes a text on command line and print it.

```
imagemagick_test.sh 00:11:22:AB:CD:EF "Hëllø, wörld!"
```

![helloworld.png](helloworld.png)

The "Hëllø, wörld!" image with UTF-8 letters printed.

The image raster format is the same as [Netpbm](https://en.wikipedia.org/wiki/Netpbm)
`Portable BitMap` type `P4`. A header of a `.pbm` would look like:

```
P4
384 20
...(binary data)
```

In the script the two first lines from the above is cut off
and then prefixed with raster image command and the graphics can be printed.

## Bluetooth chip

The bluetooth chip inside is a
[Microchip IS1678 Bluetooth Dual-Mode System on a Chip](https://www.microchip.com/en-us/product/is1678)
which means the chip both support Bluetooth Classic BR/EDR and
BLE/LE Bluetooth Low Energy (GATT).

The chip has a UART interface (TX/RX) where the backend MCU can
get a simple UART connection and then handling the printing.

## See also

- [ESC/POS Documentation for Pyramid Printers](https://escpos.readthedocs.io/en/latest/commands.html) description of most commands used by cat printers
- [EPSON ESC/P Reference Manual December 1997](https://files.support.epson.com/pdf/general/escp2ref.pdf) - just for reference, not the codes used in cat printers
