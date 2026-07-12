"""List the cards of one set, with the fields the fusion rule reads.

Prints level, DP, trait and colours, one card per row. The trait is the card's
ord = 0 card_types row resolved through DigimonTraits.lua into the group the
fusion rule actually compares -- Agumon's raw "Reptile" shows up as "Dinosaur".

    python tools/list_set.py EX11              # the Digimon of EX-11
    python tools/list_set.py EX11 --all        # Tamers, Options and DigiEggs too
    python tools/list_set.py EX11 --with-art   # only the cards the game can draw
    python tools/list_set.py EX11 --raw-trait  # the raw DCGO trait, ungrouped
    python tools/list_set.py EX11 --csv        # comma-separated instead of aligned
"""

import argparse
import csv
import re
import sqlite3
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

DEFAULT_DB = REPO / "digimon.cdb"
DEFAULT_TRAITS = REPO / "DigimonTraits.lua"

QUERY = """
    SELECT c.card_id,
           c.name_en,
           c.card_kind_name,
           c.level,
           c.dp,
           (SELECT t.type_en FROM card_types t
             WHERE t.card_id = c.card_id AND t.ord = 0),
           (SELECT group_concat(color_name, '/') FROM
                (SELECT color_name FROM card_colors
                  WHERE card_id = c.card_id ORDER BY ord)),
           c.has_art
      FROM cards c
     WHERE c.set_code = ?
       AND (? = 0 OR c.card_kind = 0)
       AND (? = 0 OR c.has_art = 1)
     ORDER BY c.level, c.card_number
"""

HEADER = ["Card", "Name", "Kind", "Lvl", "DP", "Trait", "Colors", "Art"]

GROUP = re.compile(r'^ {4}(?:\["([^"]+)"\]|(\w+)) = \{')
RAW_TRAIT = re.compile(r'^ {8}"([^"]+)"')


def loadTraitGroups(path):
    """The raw trait -> group map, read out of DigimonTraits.lua so the game and this
    script cannot drift apart. Only the `local traits` table is parsed."""
    groups = {}
    group = None
    for line in path.read_text(encoding="utf-8").splitlines():
        header = GROUP.match(line)
        if header:
            group = header.group(1) or header.group(2)
            continue
        raw = RAW_TRAIT.match(line)
        if raw and group:
            groups[raw.group(1)] = group
    return groups


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("set_code", help="the set to list, e.g. EX11")
    ap.add_argument("--all", action="store_true", help="include Tamers, Options and DigiEggs")
    ap.add_argument("--with-art", action="store_true", help="only cards with art, i.e. the ones the game uses")
    ap.add_argument("--raw-trait", action="store_true", help="show the raw DCGO trait instead of its group")
    ap.add_argument("--csv", action="store_true", help="print CSV instead of an aligned table")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="the Digimon database")
    ap.add_argument("--traits", type=Path, default=DEFAULT_TRAITS, help="the Lua trait grouping")
    args = ap.parse_args()

    db = sqlite3.connect(args.db)
    cards = db.execute(QUERY, (args.set_code, 0 if args.all else 1, 1 if args.with_art else 0)).fetchall()
    db.close()

    if not cards:
        sys.exit(f"no cards in set {args.set_code}")

    groups = loadTraitGroups(args.traits)

    rows = []
    for card_id, name, kind, level, dp, trait, colors, has_art in cards:
        #a Digimon's raw trait must be in the map -- an unmapped one is what DigimonTraits
        #refuses to bucket silently, so surface it here too. Tamers and Options have none
        if trait and not args.raw_trait and kind == "Digimon":
            trait = groups[trait]
        rows.append(
            [card_id, name, kind, str(level), str(dp), trait or "", colors or "", "yes" if has_art else "no"]
        )

    if args.csv:
        out = csv.writer(sys.stdout, lineterminator="\n")
        out.writerow(HEADER)
        out.writerows(rows)
        return

    widths = [max(len(row[i]) for row in [HEADER] + rows) for i in range(len(HEADER))]
    for row in [HEADER] + rows:
        print("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)).rstrip())
    print(f"\n{len(rows)} cards")


if __name__ == "__main__":
    sys.exit(main())
