"""Makes a label-less copy of the Initial D name shell.

Usage: python blank_name_shell.py wwwroot/id/name_background.png wwwroot/id/name_background_blank.png

name_background.png has "DRIVER" and "Pos" baked into its black header strip. The strip is
uniform vertically apart from the text, so each label box is refilled column by column from
a text-free row of the same column, which keeps the shell's faded ends. Requires Pillow.
"""
import sys

from PIL import Image

# (x range, y range, clean source row) per label, for the 500x70 shell.
BOXES = [
    # "DRIVER" sits on a darker tab (rows 3-19) at the faded left end; refill from the tab.
    (range(30, 112), range(3, 17), 18),
    (range(328, 372), range(19, 37), 10),  # "Pos", right of the name
]


def main(src, out):
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for xs, ys, source in BOXES:
        for x in xs:
            for y in ys:
                px[x, y] = px[x, source]

    # The header is near-black; anything brighter left in it is label residue.
    left = [(x, y) for x in range(im.size[0]) for y in range(3, 39)
            if px[x, y][3] > 30 and max(px[x, y][:3]) > 35]
    if left:
        sys.exit(f'label residue left at {left[:5]}')
    im.save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
