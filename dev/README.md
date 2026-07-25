# Developer

Here are some information relevant to developers.

## bash_test.sh

[bash_test.sh](bash_test.sh)
is a simple BASH script which print a demo to the printer.

This test requires `bluez` installed:

```
sudo apt install bluez
```

From the `bluez` package `rfcomm` will be used to bind the
bluetooth MAC address to character device `/dev/rfcomm0`.

```
bash_test.sh 00:11:22:AB:CD:EF
```

The image will look like the image below:

![dash-bar.png](dash-bar.png)


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

## See also

- [ESC/POS Documentation for Pyramid Printers](https://escpos.readthedocs.io/en/latest/commands.html) description of most commands used by cat printers
- [EPSON ESC/P Reference Manual December 1997](https://files.support.epson.com/pdf/general/escp2ref.pdf) - just for reference, not the codes used in cat printers
