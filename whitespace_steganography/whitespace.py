#!/usr/bin/env python3

# Simple demonstration of hiding data by using invisible unicode characters.
# Uses ZWSP and ZWNJ to encode either a binary zero or a binary one for each bit
# of the input data. The bits are separated by a ZWJ.
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Important note: this is not a very "secret" way to hide data, and it is
# **NOT** any form of encryption! There's a reason this is in my "experiments"
# repo. Anyone with a passing knowledge of plain text files can tell that
# there's something funny going on (for one, the enormous file size produced).
# Anyone smart enough to operate a hex editor can probably figure out the
# encoding scheme. So if it wasn't obvious, don't use this for anything
# sensitive, EVER.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# The hidden data are simply appended to the text, this way when cursoring
# around the text, the expected behaviour is seen. If the hidden data were mixed
# in with the text in a lot of editors you'd have to cursor multiple times to to
# move a single character, which isn't very "hidden".
#
# The hidden data are processed as binary, so in theory any encoding may be
# used, but it only really makes sense for unicode-encoded data to be used for
# hiding. A random section of UTF-8 data on the end of most file types is
# unlikely to be very "hidden", and most likely would make the output malformed.

import argparse
import pathlib

ZWSP = '\u200b'
ZWNJ = '\u200c'
ZWJ = '\u200d'
SENTINEL_SEQUENCE = [0xaa, 0x55]

def space_encode(input):
    return f'{input:08b}'.replace('1', ZWSP).replace('0', ZWNJ)

def space_decode(input):
    return int(input.replace(ZWSP, '1').replace(ZWNJ, '0'), 2)

def decode(inpath, outpath):
    """
    Decode an appropriately encoded file. Requires that a sentinel sequence be
    present.
    """
    with open(inpath, 'r', encoding='utf-8') as infile, open(outpath, 'wb') as outfile:
        data = infile.read()

        encoded_sentinel = ZWJ.join([space_encode(x) for x in SENTINEL_SEQUENCE])
        index = data.find(encoded_sentinel)

        if index == -1:
            raise SystemExit("Invalid input data, no sentinel sequence exists")

        outfile.write(bytes((space_decode(x) for x in data[index+len(encoded_sentinel)+1:].split(ZWJ))))

def encode(inpath, outpath, plainpath):
    """
    Hide input in the output file, encoding with unicode space characters. If
    plain is not None, then it will be prepended to the output, allowing for
    "hiding" data in the plain text file.
    """
    with open(inpath, 'rb') as infile, open(outpath, 'w', encoding='utf-8') as outfile:
        data = infile.read()

        if plainpath is not None:
            with open(plainpath, 'r') as plainfile:
                outfile.write(plainfile.read())

            # ensure text ends with a newline to prevent weirdness caused by
            # unicode characters doing what they're meant to and changing
            # whitespace
            outfile.write('\n')

        encoded_data = [space_encode(x) for x in SENTINEL_SEQUENCE]
        encoded_data.extend([space_encode(x) for x in data])
        outfile.write(ZWJ.join(encoded_data))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Encode or decode files with hidden whitespace data')
    parser.add_argument('mode', type=str, help='The mode to operate in. \'encode\' takes data and hides it while \'decode\' reveals it', choices=['encode', 'decode'])
    parser.add_argument('input_file', help='The file to take the input data from', type=pathlib.Path)
    parser.add_argument('output_file', help='The file to write the result to', type=pathlib.Path)
    parser.add_argument('--plain', help='The plain-text file to hide the data in. Only valid if encoding', type=pathlib.Path)

    args = parser.parse_args()

    if args.mode == 'decode' and args.plain is not None:
        parser.error('Must only specify plaintext in encode mode')

    if args.mode == 'encode':
        encode(args.input_file, args.output_file, args.plain)
    elif args.mode == 'decode':
        decode(args.input_file, args.output_file)
