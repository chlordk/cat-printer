#! /usr/bin/env python3

"""
cat-printer

Print images and text on YHK/Cat Bluetooth thermal printers.

Copyright
  * 2024 Abhinav Golwalkar https://github.com/abhigkar/YHK-Cat-Thermal-Printer
  * 2026 Hans Schou https://github.com/fun6400/cat-printer

License GPLv3
"""

import argparse
import configparser
import io
import re
import socket
import sys
import PIL.Image
import PIL.ImageDraw
import PIL.ImageFont
import PIL.ImageChops
import PIL.ImageOps
from pathlib import Path
from time import sleep
import struct

VERSION = '1.0.0'

CONFIG_PATH = Path.home() / ".config" / "cat-printer" / "config"
MAC_RE = re.compile(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')

def load_config(verbose=False):
    config = configparser.ConfigParser()
    if CONFIG_PATH.exists():
        if verbose:
            print(f"Config file found: {CONFIG_PATH}")
        config.read(CONFIG_PATH)
    else:
        if verbose:
            print(f"Config file not found: {CONFIG_PATH}")
    return config

def parse_args():
    parser = argparse.ArgumentParser(description="Print images and text on YHK/Cat Bluetooth thermal printers.")
    parser.add_argument('--version', action='version', version=f'%(prog)s {VERSION}')
    parser.add_argument('--verbose', action='store_true',
                         help="Print progress messages while connecting and printing")
    parser.add_argument('--status', action='store_true',
                         help="Query the printer's serial number, product info, and status, "
                              "print them, then exit without printing anything")
    parser.add_argument('--mac', metavar='XX:XX:XX:XX:XX:XX',
                         help=f"Bluetooth MAC address of the printer "
                              f"(overrides 'mac' in {CONFIG_PATH})")
    parser.add_argument('--sleep', type=float, metavar='SECONDS',
                         help=f"Delay between printer commands, in seconds, default 0.5 "
                              f"(overrides 'sleep' in {CONFIG_PATH})")
    parser.add_argument('--bottom-margin', type=int, dest='bottom_margin', metavar='LINES',
                         help=f"Blank line feeds printed after the last item, default 5 "
                              f"(overrides 'bottom_margin' in {CONFIG_PATH})")
    parser.add_argument('--font', metavar='PATH',
                         help=f"Path to a TrueType font file, default '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf' "
                              f"(overrides 'font' in {CONFIG_PATH})")
    parser.add_argument('--font-size', type=int, dest='font_size', metavar='SIZE',
                         help=f"Font size in points, default 12 "
                              f"(overrides 'font_size' in {CONFIG_PATH})")
    parser.add_argument('--width', type=int, metavar='PIXELS',
                         help=f"Printer resolution in pixels, default 384 "
                              f"(overrides 'width' in {CONFIG_PATH})")
    parser.add_argument('--port', type=int, metavar='CHANNEL',
                         help=f"Bluetooth RFCOMM channel, default 2 "
                              f"(overrides 'port' in {CONFIG_PATH})")
    parser.add_argument('--file', action='append', metavar='PATH_OR_TEXT',
                         help="A JPEG/PNG/GIF image file, a UTF-8 text file, or literal text "
                              "to print if no such file exists. In literal text, '\\n' is "
                              "turned into a line break. Can be given more than once to print "
                              "several items in a row, with no bottom margin between them. "
                              'Example: --file="Hello,\\nworld\\!"')
    parser.add_argument('text', nargs='*',
                         help="Used only when --file is not given and nothing is piped in on "
                              "stdin: a file path or literal text to print, same rules as "
                              "--file. Several words are joined with spaces into one string, "
                              "e.g. cat-printer Hello, world\\!")
    return parser.parse_args()

def resolve_mac(args, config):
    mac = args.mac or config.get('printer', 'mac', fallback=None)
    if not mac:
        raise SystemExit(
            f"No MAC address given. Pass --mac=XX:XX:XX:XX:XX:XX or set it "
            f"under [printer] in {CONFIG_PATH}")
    if not MAC_RE.match(mac):
        raise SystemExit(f"'{mac}' doesn't look like a MAC address (expected XX:XX:XX:XX:XX:XX)")
    return mac

def resolve_sleep(args, config):
    if args.sleep is not None:
        return args.sleep
    return config.getfloat('printer', 'sleep', fallback=0.5)

def resolve_bottom_margin(args, config):
    if args.bottom_margin is not None:
        return args.bottom_margin
    return config.getint('printer', 'bottom_margin', fallback=5)

def resolve_font(args, config):
    return args.font or config.get('printer', 'font', fallback='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf')

def resolve_font_size(args, config):
    if args.font_size is not None:
        return args.font_size
    return config.getint('printer', 'font_size', fallback=12)

def resolve_width(args, config):
    if args.width is not None:
        return args.width
    return config.getint('printer', 'width', fallback=384)

def resolve_port(args, config):
    if args.port is not None:
        return args.port
    return config.getint('printer', 'port', fallback=2)

def resolve_sources(args):
    """Return the list of raw values to print, in order: --file entries, or a single
    positional-text entry, or (if neither is given and data is piped in) raw stdin bytes."""
    if args.file and args.text:
        raise SystemExit("Use either --file or plain text arguments, not both.")
    if args.file:
        if args.verbose:
            print(f"Input source: --file ({len(args.file)} item(s)): {args.file}")
        return args.file
    if args.text:
        text = " ".join(args.text)
        if args.verbose:
            print(f"Input source: command line text: {text!r}")
        return [text]
    if not sys.stdin.isatty():
        data = sys.stdin.buffer.read()
        if data:
            if args.verbose:
                print(f"Input source: stdin ({len(data)} bytes)")
            return [data]
    raise SystemExit("Nothing to print: pass --file=..., text/a file path as arguments, "
                      "or pipe data in on stdin.")

IMAGE_SIGNATURES = (
    (b'\xff\xd8\xff', 'JPEG'),
    (b'\x89PNG\r\n\x1a\n', 'PNG'),
    (b'GIF87a', 'GIF'),
    (b'GIF89a', 'GIF'),
)

def detect_image_type(header: bytes):
    """Return 'JPEG', 'PNG', or 'GIF' if header matches a known image signature, else None."""
    for signature, kind in IMAGE_SIGNATURES:
        if header.startswith(signature):
            return kind
    return None

def decode_reply(data: bytes):
    """Decode a raw printer reply into a clean string, dropping the trailing NUL padding."""
    return data.decode('utf-8', errors='replace').rstrip('\x00')

def resolve_print_source(file_arg):
    """Resolve one source into either a loaded PIL Image, or text to render with create_text().

    file_arg is either raw bytes (piped in on stdin) or a str (a --file/positional value).
    For bytes, or for a str that names an existing file: JPEG/PNG/GIF signature -> loaded as
    an image; otherwise -> decoded as UTF-8 text.
    For a str that doesn't name an existing file -> treated as literal text itself, with
    '\\n' turned into a line break.
    """
    if isinstance(file_arg, bytes):
        data = file_arg
        image_type = detect_image_type(data[:8])
        if image_type:
            if args.verbose:
                print(f"Detected image format: {image_type}")
            return PIL.Image.open(io.BytesIO(data))
        try:
            return data.decode('utf-8')
        except UnicodeDecodeError:
            raise SystemExit("stdin data is neither a JPEG/PNG/GIF image nor UTF-8 text")
    path = Path(file_arg)
    if path.is_file():
        data = path.read_bytes()
        image_type = detect_image_type(data[:8])
        if image_type:
            if args.verbose:
                print(f"Detected image format: {image_type} ({file_arg})")
            return PIL.Image.open(path)
        try:
            return data.decode('utf-8')
        except UnicodeDecodeError:
            raise SystemExit(
                f"'{file_arg}' exists but is neither a JPEG/PNG/GIF image "
                f"nor a UTF-8 text file")
    return file_arg.replace('\\n', '\n')

class Printer:
    """Bluetooth interface to the printer."""
    def __init__(self, mac, channel=2):
        self.mac=mac
        self.channel=channel
        self.sock=None
    def connect(self):
        self.sock=socket.socket(socket.AF_BLUETOOTH,socket.SOCK_STREAM,socket.BTPROTO_RFCOMM)
        self.sock.connect((self.mac,self.channel))
    def close(self):
        if self.sock:
            self.sock.close()
            self.sock=None
    def initialize(self):
        self.sock.send(b"\x1b\x40")
    def status(self):
        self.sock.send(b"\x1e\x47\x03"); return self.sock.recv(38)
    def serial_number(self):
        self.sock.send(b"\x1d\x67\x39"); return self.sock.recv(21)
    def product_info(self):
        self.sock.send(b"\x1d\x67\x69"); return self.sock.recv(16)
    def _start_print(self):
        self.sock.send(b"\x1d\x49\xf0\x19")
    def _end_print(self, lines=1):
        self.sock.send(b"\x0a" * lines)

def trimImage(im):
    bg = PIL.Image.new(im.mode, im.size, (255,255,255))
    diff = PIL.ImageChops.difference(im, bg)
    diff = PIL.ImageChops.add(diff, diff, 2.0)
    bbox = diff.getbbox()
    if bbox:
        return im.crop((bbox[0],bbox[1],bbox[2],bbox[3]+10)) # don't cut off the end of the image

def create_text(text, font_name="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", font_size=12):
    img = PIL.Image.new('RGB', (printerWidth, 5000), color = (255, 255, 255))
    font = PIL.ImageFont.truetype(font_name, font_size)
    if args.verbose:
        print(f"Font found: {font_name}")

    d = PIL.ImageDraw.Draw(img)
    lines = []
    for line in text.splitlines():
        lines.append(get_wrapped_text(line, font, printerWidth))
    lines = "\n".join(lines)
    d.text((0,0), lines, fill=(0,0,0), font=font)
    return trimImage(img)

def get_wrapped_text(text: str, font: PIL.ImageFont.ImageFont,
                     line_length: int):
    lines = ['']
    for word in text.split():
        line = f'{lines[-1]} {word}'.strip()
        if font.getlength(line) <= line_length:
            lines[-1] = line
        else:
            lines.append(word)
    return '\n'.join(lines)

def printImage(printer, im):
    if im.width > printerWidth:
        # image is wider than printer resolution; scale it down proportionately
        height = int(im.height * (printerWidth / im.width))
        im = im.resize((printerWidth, height))

    if im.width < printerWidth:
        # image is narrower than printer resolution; pad it out with white pixels
        padded_image = PIL.Image.new("1", (printerWidth, im.height), 1)
        padded_image.paste(im)
        im = padded_image

    im = im.rotate(180) #print it so it looks right when spewing out of the mouth

    # if image is not 1-bit, convert it
    if im.mode != '1':
        im = im.convert('1')

    # if image width is not a multiple of 8 pixels, fix that
    if im.size[0] % 8:
        im2 = PIL.Image.new('1', (im.size[0] + 8 - im.size[0] % 8,
                        im.size[1]), 'white')
        im2.paste(im, (0, 0))
        im = im2

    # Invert image, via greyscale for compatibility
    #  (no, I don't know why I need to do this)
    im = PIL.ImageOps.invert(im.convert('L'))
    # ... and now convert back to single bit
    im = im.convert('1')

    buf = b''.join((bytearray(b'\x1d\x76\x30\x00'),
                                          struct.pack('2B', int(im.size[0] / 8 % 256),
                                                      int(im.size[0] / 8 / 256)),
                                                      struct.pack('2B', int(im.size[1] % 256),
                                                                  int(im.size[1] / 256)),
                                                                  im.tobytes()))
    printer.initialize()
    sleep(sleep_between)
    printer._start_print()
    sleep(sleep_between)
    printer.sock.send(buf)
    sleep(sleep_between)


args = parse_args()
config = load_config(args.verbose)
mac = resolve_mac(args, config)
if args.verbose:
    print(f"Using MAC address: {mac}")
sleep_between = resolve_sleep(args, config)
bottom_margin = resolve_bottom_margin(args, config)
font = resolve_font(args, config)
font_size = resolve_font_size(args, config)
printerWidth = resolve_width(args, config)
port = resolve_port(args, config)

printer = Printer(mac, port)
printer.connect()

try:
    if args.verbose:
        print("Connecting to printer...")

    if args.status:
        serial = printer.serial_number()
        product = printer.product_info()
        status = printer.status()
        print(f"Serial number: {decode_reply(serial)}")
        print(f"Product info:  {decode_reply(product)}")
        print(f"Status:        {decode_reply(status)}")
        sys.exit(0)

    printer.status()
    sleep(sleep_between)

    sources = resolve_sources(args)
    for i, raw in enumerate(sources):
        source = resolve_print_source(raw)
        if isinstance(source, PIL.Image.Image):
            img = source
        else:
            img = create_text(source, font_name=font, font_size=font_size)

        printImage(printer,img)

        if i == len(sources) - 1:
            printer._end_print(bottom_margin)
            sleep(sleep_between)
finally:
    printer.close()
    if args.verbose:
        print("Printer closed")

