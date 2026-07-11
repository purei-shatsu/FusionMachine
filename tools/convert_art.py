"""Convert DCGO's Digimon card art into the form Solar2D can load.

DCGO ships card art as 430x601 `.webp`, which display.newImageRect cannot open.
This converts every card the database says has art into `digimon_pics/<card_id>.jpg`,
mirroring the `pics/<id>.jpg` layout the Yu-Gi-Oh side already uses.

Idempotent: a card whose .jpg already exists is skipped, so re-running after a DCGO
sync only converts the new sets.

    python tools/convert_art.py                 # uses the defaults below
    python tools/convert_art.py --force         # reconvert everything
"""

import argparse
import sqlite3
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent

DEFAULT_ART = Path(r"D:\Downloads\DCGO_Application\Assets\Textures\Card")
DEFAULT_DB = REPO / "digimon.cdb"
DEFAULT_OUT = REPO / "digimon_pics"

QUALITY = 85


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--art", type=Path, default=DEFAULT_ART, help="folder of <CardID>.webp art")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="the Digimon database")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output folder of .jpg art")
    ap.add_argument("--force", action="store_true", help="reconvert cards that already have a .jpg")
    args = ap.parse_args()

    args.out.mkdir(exist_ok=True)

    db = sqlite3.connect(args.db)
    cards = [row[0] for row in db.execute("SELECT card_id FROM cards WHERE has_art = 1 ORDER BY card_id")]
    db.close()

    converted = skipped = 0
    for card_id in cards:
        target = args.out / f"{card_id}.jpg"
        if target.exists() and not args.force:
            skipped += 1
            continue

        with Image.open(args.art / f"{card_id}.webp") as image:
            image.convert("RGB").save(target, "JPEG", quality=QUALITY)
        converted += 1

    print(f"converted {converted} / skipped {skipped} into {args.out}")


if __name__ == "__main__":
    sys.exit(main())
